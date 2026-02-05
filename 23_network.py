import sys
import ctypes
import subprocess
import time
import random
import re
import urllib.request
from dataclasses import dataclass

from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QObject
from PyQt6.QtGui import QColor, QPainter, QFont, QLinearGradient
from PyQt6.QtWidgets import (
    QApplication,
    QWidget,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QHBoxLayout,
    QFrame,
    QMessageBox,
    QComboBox,
)

APP_NAME = "23 Network Optimizer"
VERSION = "v1.0"

TEST_TARGETS = {
    "Cloudflare (1.1.1.1)": "1.1.1.1",
    "Google DNS (8.8.8.8)": "8.8.8.8",
    "Quad9 (9.9.9.9)": "9.9.9.9",
}

TEST_DOWNLOADS = {
    "Cloudflare 10MB": "https://speed.cloudflare.com/__down?bytes=10000000",
    "Hetzner 10MB": "https://speed.hetzner.de/10MB.bin",
}


# ===============================
# ADMIN CHECK
# ===============================

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False


# ===============================
# NETWORK WORKER
# ===============================
class NetworkWorker(QObject):
    progress = pyqtSignal(int)
    status = pyqtSignal(str)
    result = pyqtSignal(dict)
    error = pyqtSignal(str)

    def __init__(self, ping_target: str, download_url: str):
        super().__init__()
        self.ping_target = ping_target
        self.download_url = download_url

    def run(self):
        try:
            self.status.emit("Measuring latency...")
            latency = self.measure_latency(self.ping_target)
            self.progress.emit(35)

            self.status.emit("Testing download speed...")
            speed = self.measure_download_speed(self.download_url)
            self.progress.emit(85)

            stability = self.calculate_stability(latency, speed)
            self.progress.emit(100)

            self.result.emit(
                {
                    "latency_ms": latency.average_ms,
                    "jitter_ms": latency.jitter_ms,
                    "packet_loss": latency.packet_loss,
                    "download_mbps": speed,
                    "stability": stability,
                }
            )
        except Exception as exc:
            self.error.emit(str(exc))

    def measure_latency(self, target: str, count: int = 4):
        cmd = ["ping", "-n", str(count), target]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        output = proc.stdout + proc.stderr
        times = [int(match.group(1)) for match in re.finditer(r"time[=<](\d+)ms", output)]
        avg_match = re.search(r"Average = (\d+)ms", output)
        loss_match = re.search(r"\((\d+)% loss\)", output)
        if avg_match:
            average_ms = int(avg_match.group(1))
        elif times:
            average_ms = int(sum(times) / len(times))
        else:
            raise RuntimeError("Unable to parse latency results.")
        jitter_ms = max(times) - min(times) if times else 0
        packet_loss = int(loss_match.group(1)) if loss_match else 0
        return LatencyResult(average_ms, jitter_ms, packet_loss)

    def measure_download_speed(self, url: str, timeout: int = 20):
        start = time.time()
        total_bytes = 0
        chunk_size = 256 * 1024
        with urllib.request.urlopen(url, timeout=timeout) as response:
            while True:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                total_bytes += len(chunk)
        elapsed = max(time.time() - start, 0.1)
        mbps = (total_bytes * 8) / (elapsed * 1_000_000)
        return round(mbps, 2)

    @staticmethod
    def calculate_stability(latency: "LatencyResult", speed_mbps: float):
        latency_score = max(0, 100 - latency.average_ms)
        jitter_score = max(0, 100 - latency.jitter_ms * 2)
        loss_score = max(0, 100 - latency.packet_loss * 5)
        speed_score = min(100, speed_mbps * 4)
        return int((latency_score + jitter_score + loss_score + speed_score) / 4)


# ===============================
# SAFE RESET WORKER
# ===============================
class ResetWorker(QObject):
    status = pyqtSignal(str)
    done = pyqtSignal()
    error = pyqtSignal(str)

    def run(self):
        try:
            self.status.emit("Flushing DNS cache...")
            subprocess.run(
                "ipconfig /flushdns",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=8,
            )
            self.status.emit("Resetting Winsock...")
            subprocess.run(
                "netsh winsock reset",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
            self.status.emit("Resetting IP stack...")
            subprocess.run(
                "netsh int ip reset",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
            self.status.emit("Restoring TCP autotuning...")
            subprocess.run(
                "netsh int tcp set global autotuninglevel=normal",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
            self.done.emit()
        except Exception as exc:
            self.error.emit(str(exc))


@dataclass
class LatencyResult:
    average_ms: int
    jitter_ms: int
    packet_loss: int


# ===============================
# UI COMPONENTS
# ===============================
class StatCard(QFrame):
    def __init__(self, title, value="0", unit=""):
        super().__init__()
        self.setFixedSize(180, 90)
        self.setStyleSheet("QFrame { background: rgba(10,10,10,0.4); border-radius: 12px; }")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(2)

        self.value_label = QLabel(value)
        self.value_label.setFont(QFont("Segoe UI", 22, QFont.Weight.Bold))
        self.value_label.setStyleSheet("color: #38bdf8; border: none;")
        self.value_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        unit_label = QLabel(unit)
        unit_label.setFont(QFont("Segoe UI", 10))
        unit_label.setStyleSheet("color: #bae6fd; border: none;")
        unit_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        title_label = QLabel(title)
        title_label.setFont(QFont("Segoe UI", 9))
        title_label.setStyleSheet("color: #e0f2fe; border: none;")
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        layout.addWidget(self.value_label)
        layout.addWidget(unit_label)
        layout.addWidget(title_label)

    def set_value(self, value):
        self.value_label.setText(str(value))


class GlowButton(QPushButton):
    def __init__(self, text):
        super().__init__(text)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(
            """
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #0ea5e9, stop:1 #0284c7);
                color: white;
                font-size: 16px;
                font-weight: bold;
                font-family: 'Segoe UI';
                padding: 14px 32px;
                border-radius: 14px;
                border: none;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #38bdf8, stop:1 #0ea5e9);
            }
            QPushButton:disabled {
                background: #0c4a6e;
                color: #bae6fd;
            }
            """
        )


class NetworkOptimizerUI(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"{APP_NAME} – {VERSION}")
        self.setFixedSize(1040, 720)
        self._init_ui()

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(18)

        title = QLabel(APP_NAME)
        title.setFont(QFont("Segoe UI", 42, QFont.Weight.Bold))
        title.setStyleSheet("color: white; letter-spacing: 2px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)

        subtitle = QLabel("Latency, stability, and throughput diagnostics")
        subtitle.setFont(QFont("Segoe UI", 12))
        subtitle.setStyleSheet("color: #e0f2fe;")
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)

        badges_layout = QHBoxLayout()
        badges_layout.setSpacing(10)
        badges_layout.addStretch()
        for badge_text in ("Windows 10/11", "Wi-Fi & Ethernet", "Safe", "Universal"):
            badge = QLabel(badge_text)
            badge.setFont(QFont("Segoe UI", 9, QFont.Weight.Bold))
            badge.setStyleSheet(
                "color: #bae6fd; background: rgba(14,116,144,0.5);"
                "padding: 4px 10px; border-radius: 10px; border: 1px solid #0e7490;"
            )
            badges_layout.addWidget(badge)
        badges_layout.addStretch()

        header_line = QFrame()
        header_line.setFixedHeight(2)
        header_line.setStyleSheet(
            "background: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
            "stop:0 rgba(14,165,233,0), stop:0.5 rgba(14,165,233,0.6), stop:1 rgba(14,165,233,0));"
        )

        stats_layout = QHBoxLayout()
        stats_layout.setSpacing(20)
        self.latency_card = StatCard("Latency", "--", "ms")
        self.jitter_card = StatCard("Jitter", "--", "ms")
        self.download_card = StatCard("Download", "--", "Mbps")
        self.stability_card = StatCard("Stability", "--", "%")
        stats_layout.addStretch()
        for card in (
            self.latency_card,
            self.jitter_card,
            self.download_card,
            self.stability_card,
        ):
            stats_layout.addWidget(card)
        stats_layout.addStretch()

        selector_layout = QHBoxLayout()
        selector_layout.setSpacing(12)
        selector_layout.addStretch()
        self.ping_selector = QComboBox()
        self.ping_selector.addItems(TEST_TARGETS.keys())
        self.ping_selector.setFixedWidth(220)
        self.ping_selector.setStyleSheet(
            "QComboBox { background: #0f172a; color: white; padding: 6px; border-radius: 8px; }"
        )

        self.download_selector = QComboBox()
        self.download_selector.addItems(TEST_DOWNLOADS.keys())
        self.download_selector.setFixedWidth(220)
        self.download_selector.setStyleSheet(
            "QComboBox { background: #0f172a; color: white; padding: 6px; border-radius: 8px; }"
        )

        selector_layout.addWidget(QLabel("Ping Target:"))
        selector_layout.addWidget(self.ping_selector)
        selector_layout.addSpacing(12)
        selector_layout.addWidget(QLabel("Download Test:"))
        selector_layout.addWidget(self.download_selector)
        selector_layout.addStretch()

        self.run_button = GlowButton("RUN NETWORK TEST")
        self.run_button.clicked.connect(self.run_test)
        self.reset_button = GlowButton("APPLY SAFE RESET")
        self.reset_button.clicked.connect(self.apply_reset)

        button_layout = QHBoxLayout()
        button_layout.setSpacing(18)
        button_layout.addStretch()
        button_layout.addWidget(self.run_button)
        button_layout.addWidget(self.reset_button)
        button_layout.addStretch()

        self.status_label = QLabel("Ready for diagnostics")
        self.status_label.setFont(QFont("Segoe UI", 12, QFont.Weight.Bold))
        self.status_label.setStyleSheet("color: #7dd3fc;")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.progress_label = QLabel("No tests running")
        self.progress_label.setFont(QFont("Segoe UI", 10))
        self.progress_label.setStyleSheet("color: #bae6fd;")
        self.progress_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.tip_label = QLabel(
            "Tip: Run tests while connected to your usual Wi-Fi or Ethernet for realistic results."
        )
        self.tip_label.setFont(QFont("Segoe UI", 9))
        self.tip_label.setStyleSheet("color: #e2e8f0;")
        self.tip_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        layout.addWidget(title)
        layout.addWidget(subtitle)
        layout.addLayout(badges_layout)
        layout.addWidget(header_line)
        layout.addSpacing(10)
        layout.addLayout(stats_layout)
        layout.addSpacing(8)
        layout.addLayout(selector_layout)
        layout.addSpacing(12)
        layout.addLayout(button_layout)
        layout.addWidget(self.status_label)
        layout.addWidget(self.progress_label)
        layout.addWidget(self.tip_label)

        self._apply_background_style()

    def _apply_background_style(self):
        self.setStyleSheet(
            """
            QWidget {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #0f172a, stop:0.45 #020617, stop:1 #0b1120);
            }
            QLabel {
                color: #e2e8f0;
                font-family: 'Segoe UI';
            }
            """
        )

    def paintEvent(self, event):
        painter = QPainter(self)
        gradient = QLinearGradient(0, 0, self.width(), self.height())
        gradient.setColorAt(0, QColor(2, 6, 23))
        gradient.setColorAt(0.5, QColor(15, 23, 42))
        gradient.setColorAt(1, QColor(12, 74, 110))
        painter.fillRect(self.rect(), gradient)
        painter.setPen(Qt.PenStyle.NoPen)
        for _ in range(80):
            x = random.randint(0, self.width())
            y = random.randint(0, self.height())
            radius = random.randint(1, 2)
            color = QColor(186, 230, 253, random.randint(50, 120))
            painter.setBrush(color)
            painter.drawEllipse(x, y, radius, radius)

    def run_test(self):
        self.run_button.setEnabled(False)
        self.reset_button.setEnabled(False)
        self.status_label.setText("Running diagnostics...")
        self.progress_label.setText("Collecting latency data")

        ping_target = TEST_TARGETS[self.ping_selector.currentText()]
        download_url = TEST_DOWNLOADS[self.download_selector.currentText()]
        self.worker = NetworkWorker(ping_target, download_url)
        self.worker.status.connect(self.update_status)
        self.worker.progress.connect(self.update_progress)
        self.worker.result.connect(self.show_results)
        self.worker.error.connect(self.handle_error)
        QTimer.singleShot(0, self.worker.run)

    def apply_reset(self):
        if not is_admin():
            QMessageBox.warning(
                self,
                "Admin Required",
                "Safe reset needs administrator privileges. Please run as admin.",
            )
            return
        self.run_button.setEnabled(False)
        self.reset_button.setEnabled(False)
        self.status_label.setText("Applying safe reset...")
        self.progress_label.setText("This may take a few seconds")
        self.reset_worker = ResetWorker()
        self.reset_worker.status.connect(self.update_status)
        self.reset_worker.done.connect(self.reset_done)
        self.reset_worker.error.connect(self.handle_error)
        QTimer.singleShot(0, self.reset_worker.run)

    def update_status(self, text):
        self.progress_label.setText(text)

    def update_progress(self, value):
        if value >= 85:
            self.progress_label.setText("Finalizing results...")

    def show_results(self, data):
        self.latency_card.set_value(data["latency_ms"])
        self.jitter_card.set_value(data["jitter_ms"])
        self.download_card.set_value(data["download_mbps"])
        self.stability_card.set_value(data["stability"])

        self.status_label.setText("Network diagnostics complete")
        self.progress_label.setText("Ready for another test")
        self.run_button.setEnabled(True)
        self.reset_button.setEnabled(True)

    def reset_done(self):
        self.status_label.setText("Safe reset applied")
        self.progress_label.setText("Restart may be required for all changes")
        QMessageBox.information(
            self,
            "Reset Complete",
            "Network reset applied. Restart Windows for full effect.",
        )
        self.run_button.setEnabled(True)
        self.reset_button.setEnabled(True)

    def handle_error(self, error_msg):
        self.status_label.setText("❌ Operation failed")
        self.progress_label.setText(error_msg)
        QMessageBox.critical(self, "Error", error_msg)
        self.run_button.setEnabled(True)
        self.reset_button.setEnabled(True)


# ===============================
# ENTRY POINT
# ===============================
if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = NetworkOptimizerUI()
    window.show()
    sys.exit(app.exec())
