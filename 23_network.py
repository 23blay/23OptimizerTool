import sys
import ctypes
import subprocess
import time
import random
import re
import urllib.request
from urllib.parse import urlparse
import math
import json
from dataclasses import dataclass
from threading import Thread

from PyQt6.QtCore import (
    Qt,
    QTimer,
    QRectF,
    pyqtSignal,
    QObject,
    QPropertyAnimation,
    QEasingCurve,
    pyqtProperty,
    QSequentialAnimationGroup,
    QPointF,
)
from PyQt6.QtGui import QColor, QPainter, QFont, QRadialGradient, QPen
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
    QGraphicsOpacityEffect,
    QProgressBar,
)

APP_NAME = "23 Network Optimizer"
VERSION = "v1.2"

TEST_TARGETS = {
    "Cloudflare (1.1.1.1)": "1.1.1.1",
    "Google DNS (8.8.8.8)": "8.8.8.8",
    "Quad9 (9.9.9.9)": "9.9.9.9",
}

TEST_DOWNLOADS = {
    "Cloudflare 25MB": "https://speed.cloudflare.com/__down?bytes=25000000",
    "Cloudflare 10MB": "https://speed.cloudflare.com/__down?bytes=10000000",
    "Hetzner 10MB": "https://speed.hetzner.de/10MB.bin",
    "ThinkBroadband 20MB": "https://download.thinkbroadband.com/20MB.zip",
    "Tele2 10MB": "https://speedtest.tele2.net/10MB.zip",
}

SPEEDTEST_SERVERS_URL = "https://www.speedtest.net/api/js/servers?engine=js&limit=10"

PRIMARY_RED = QColor(239, 68, 68)
SECONDARY_RED = QColor(220, 38, 38)
SOFT_RED = QColor(248, 113, 113)


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
class DiagnosticsWorker(QObject):
    progress = pyqtSignal(int)
    status = pyqtSignal(str)
    substatus = pyqtSignal(str)
    result = pyqtSignal(dict)
    error = pyqtSignal(str)

    def __init__(self, apply_reset: bool):
        super().__init__()
        self.apply_reset = apply_reset
        self.nic_info = self.get_nic_info()

    def run(self):
        try:
            self.status.emit("Smart target selection...")
            best_target = self.select_best_target()
            speedtest_server = self.select_speedtest_server()
            download_endpoint = self.select_download_url()
            if speedtest_server is None and download_endpoint is None:
                self.substatus.emit("No speedtest endpoints reachable, continuing without speed test")
            self.progress.emit(10)

            self.status.emit("Running baseline test...")
            nic_text = self.format_nic_info()
            self.substatus.emit(f"Target: {best_target['label']} • {nic_text}")
            baseline = self.run_single_test(best_target["ip"], speedtest_server, download_endpoint)
            self.progress.emit(45)

            reset_applied = False
            if self.apply_reset:
                if not is_admin():
                    self.substatus.emit("Reset skipped: admin required")
                else:
                    self.status.emit("Applying safe reset...")
                    self.substatus.emit("Flushing DNS / Resetting network stack")
                    self.apply_safe_reset()
                    self.status.emit("Applying safe NIC optimizations...")
                    self.substatus.emit("Optimizing TCP settings (safe)")
                    self.apply_safe_optimizations()
                    reset_applied = True
                self.progress.emit(65)

            self.status.emit("Running post-reset test...")
            self.substatus.emit(f"Target: {best_target['label']} • {nic_text}")
            after = self.run_single_test(best_target["ip"], speedtest_server, download_endpoint)
            self.progress.emit(100)

            self.result.emit(
                {
                    "baseline": baseline,
                    "after": after,
                    "target_label": best_target["label"],
                    "reset_applied": reset_applied,
                    "nic_info": self.nic_info,
                    "download_label": download_endpoint["label"] if download_endpoint else "Unavailable",
                    "speedtest_label": speedtest_server["label"]
                    if speedtest_server
                    else "Unavailable",
                }
            )
        except Exception as exc:
            self.error.emit(str(exc))

    def select_best_target(self):
        best = None
        targets = list(TEST_TARGETS.items())
        gateway = self.get_default_gateway()
        if gateway:
            targets.insert(0, ("Default Gateway", gateway))
        for label, ip in targets:
            try:
                self.substatus.emit(f"Probing {label}")
                latency = self.measure_latency(ip, count=1, timeout=1000)
                if best is None or latency.average_ms < best["latency"]:
                    best = {"label": label, "ip": ip, "latency": latency.average_ms}
            except Exception:
                continue
        if not best:
            raise RuntimeError("No reachable targets. Check network connection.")
        return best

    def select_download_url(self):
        for label, url in TEST_DOWNLOADS.items():
            if self.probe_download_url(label, url):
                return {"label": label, "url": url}
        return None

    def probe_download_url(self, label: str, url: str):
        try:
            self.substatus.emit(f"Checking {label}")
            request = urllib.request.Request(url, headers={"Range": "bytes=0-1023"})
            with urllib.request.urlopen(request, timeout=6) as response:
                return response.status in (200, 206)
        except Exception:
            return False

    def run_single_test(self, target: str, speedtest_server, download_endpoint):
        self.status.emit("Measuring latency...")
        latency = self.measure_latency(target)
        self.progress.emit(30)

        self.status.emit("Testing download speed...")
        if speedtest_server:
            speed = self.measure_speedtest_download(speedtest_server)
        elif download_endpoint:
            speed = self.measure_download_speed(download_endpoint["url"])
        else:
            self.substatus.emit("Download test skipped (no endpoint reachable)")
            speed = 0.0
        self.progress.emit(60)

        stability = self.calculate_stability(latency, speed)
        return TestResult(latency, speed, stability)

    def measure_latency(self, target: str, count: int = 4, timeout: int = 2000):
        cmd = ["ping", "-n", str(count), "-w", str(timeout), target]
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

    def measure_download_speed(self, url: str, duration: float = 6.0):
        start = time.time()
        total_bytes = 0
        chunk_size = 256 * 1024
        with urllib.request.urlopen(url, timeout=20) as response:
            response.read(64 * 1024)
            while time.time() - start < duration:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                total_bytes += len(chunk)
        elapsed = max(time.time() - start, 0.1)
        mbps = (total_bytes * 8) / (elapsed * 1_000_000)
        return round(mbps, 2)

    def measure_speedtest_download(self, server: dict, duration: float = 8.0):
        base_url = server["base_url"]
        sizes = [35000000, 25000000, 10000000]
        start = time.time()
        total_bytes = 0
        chunk_size = 256 * 1024
        with urllib.request.urlopen(
            urllib.request.Request(f"{base_url}/download?size={sizes[0]}"),
            timeout=20,
        ) as response:
            response.read(64 * 1024)
            while time.time() - start < duration:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                total_bytes += len(chunk)
        elapsed = max(time.time() - start, 0.1)
        mbps = (total_bytes * 8) / (elapsed * 1_000_000)
        return round(mbps, 2)

    def apply_safe_reset(self):
        subprocess.run(
            "ipconfig /flushdns",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=8,
        )
        subprocess.run(
            "netsh winsock reset",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
        subprocess.run(
            "netsh int ip reset",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
        subprocess.run(
            "netsh int tcp set global autotuninglevel=normal",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )

    def apply_safe_optimizations(self):
        safe_cmds = [
            "netsh int tcp set global autotuninglevel=normal",
            "netsh int tcp set heuristics disabled",
            "netsh int tcp set global congestionprovider=ctcp",
            "netsh int tcp set global rss=enabled",
            "netsh int tcp set global rsc=disabled",
            "netsh int tcp set global ecncapability=disabled",
            "netsh int tcp set global timestamps=disabled",
            "netsh int tcp set global initialRto=2000",
        ]
        for cmd in safe_cmds:
            subprocess.run(
                cmd,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )

    @staticmethod
    def calculate_stability(latency: "LatencyResult", speed_mbps: float):
        latency_score = max(0, 100 - latency.average_ms)
        jitter_score = max(0, 100 - latency.jitter_ms * 2)
        loss_score = max(0, 100 - latency.packet_loss * 5)
        speed_score = min(100, speed_mbps * 4)
        return int((latency_score + jitter_score + loss_score + speed_score) / 4)

    def get_default_gateway(self):
        try:
            output = subprocess.run(
                "ipconfig",
                shell=True,
                capture_output=True,
                text=True,
                timeout=6,
            ).stdout
            match = re.search(r"Default Gateway[ .]*: ([0-9.]+)", output)
            return match.group(1) if match else None
        except Exception:
            return None

    def select_speedtest_server(self):
        servers = self.get_speedtest_servers()
        if not servers:
            return None
        best = None
        for server in servers:
            host = server.get("host")
            if not host:
                continue
            try:
                self.substatus.emit(f"Probing {server['label']}")
                latency = self.measure_latency(host, count=1, timeout=1000)
                if best is None or latency.average_ms < best["latency"]:
                    best = {"latency": latency.average_ms, **server}
            except Exception:
                continue
        return best

    def get_speedtest_servers(self):
        try:
            with urllib.request.urlopen(SPEEDTEST_SERVERS_URL, timeout=8) as response:
                raw = response.read().decode("utf-8")
            data = json.loads(raw)
            servers = []
            for item in data:
                url = item.get("url")
                if not url:
                    continue
                parsed = urlparse(url)
                base_url = url.rsplit("/", 1)[0]
                servers.append(
                    {
                        "label": f\"{item.get('name', 'Server')}, {item.get('country', '')}\",
                        "host": parsed.hostname,
                        "base_url": base_url,
                    }
                )
            return servers
        except Exception:
            return []

    def get_nic_info(self):
        try:
            cmd = (
                "powershell -Command "
                "\"Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | "
                "Sort-Object -Property LinkSpeed -Descending | "
                "Select-Object -First 1 -Property Name,InterfaceDescription,LinkSpeed,MacAddress | "
                "ConvertTo-Json\""
            )
            output = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=8,
            ).stdout.strip().splitlines()
            raw = "\n".join(output)
            if raw:
                data = json.loads(raw)
                return {
                    "description": data.get("InterfaceDescription", "Unknown adapter"),
                    "link_speed": data.get("LinkSpeed", "Unknown"),
                    "name": data.get("Name", "Unknown"),
                    "mac": data.get("MacAddress", "Unknown"),
                }
        except Exception:
            return {"description": "Unknown adapter", "link_speed": "Unknown"}
        return {"description": "Unknown adapter", "link_speed": "Unknown"}

    def format_nic_info(self):
        if not self.nic_info:
            return "Adapter: Unknown"
        description = self.nic_info.get("description", "Unknown adapter")
        speed = self.nic_info.get("link_speed", "Unknown")
        return f"Adapter: {description} • Link: {speed}"


@dataclass
class LatencyResult:
    average_ms: int
    jitter_ms: int
    packet_loss: int


@dataclass
class TestResult:
    latency: LatencyResult
    download_mbps: float
    stability: int


# ===============================
# ANIMATED PARTICLE SYSTEM
# ===============================
class Particle:
    def __init__(self, x, y, vx, vy, size, color):
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.size = size
        self.color = color
        self.life = 1.0


class PulseRing:
    def __init__(self, x, y, max_radius=220, speed=6, color=QColor(239, 68, 68)):
        self.x = x
        self.y = y
        self.radius = 0
        self.max_radius = max_radius
        self.speed = speed
        self.alpha = 160
        self.color = color


# ===============================
# GALAXY BACKGROUND WITH NEBULA
# ===============================
class GalaxyBackground(QWidget):
    def __init__(self):
        super().__init__()
        self.stars = []
        self.particles = []
        self.comets = []
        self.pulse_rings = []
        self.nebula_offset = 0
        self.scan_phase = 0

        for _ in range(200):
            self.stars.append(
                {
                    "x": random.randint(0, 1200),
                    "y": random.randint(0, 800),
                    "size": random.uniform(1, 3),
                    "speed": random.uniform(0.3, 1.5),
                    "brightness": random.uniform(0.3, 1.0),
                    "twinkle_speed": random.uniform(0.02, 0.08),
                    "twinkle_phase": random.uniform(0, 6.28),
                }
            )

        self.timer = QTimer(self)
        self.timer.setTimerType(Qt.TimerType.PreciseTimer)
        self.timer.timeout.connect(self.animate)
        self.timer.start(16)

    def add_particle_burst(self, x, y, count=20):
        colors = [PRIMARY_RED, SECONDARY_RED, SOFT_RED]
        for _ in range(count):
            speed = random.uniform(2, 6)
            self.particles.append(
                Particle(
                    x,
                    y,
                    speed * random.uniform(-1, 1),
                    speed * random.uniform(-1, 1),
                    random.uniform(2, 5),
                    random.choice(colors),
                )
            )

    def add_pulse_ring(self, x, y, color=SOFT_RED):
        self.pulse_rings.append(PulseRing(x, y, color=color))

    def spawn_comet(self):
        if random.random() < 0.03:
            self.comets.append(
                {
                    "x": random.randint(0, self.width()),
                    "y": random.randint(-200, 0),
                    "vx": random.uniform(-3, -1),
                    "vy": random.uniform(4, 7),
                    "life": 1.0,
                }
            )

    def animate(self):
        for star in self.stars:
            star["y"] += star["speed"]
            if star["y"] > self.height():
                star["x"] = random.randint(0, self.width())
                star["y"] = 0
                star["brightness"] = random.uniform(0.3, 1.0)

            star["twinkle_phase"] += star["twinkle_speed"]
            star["brightness"] = 0.4 + 0.6 * abs(math.sin(star["twinkle_phase"]))

        for particle in self.particles[:]:
            particle.x += particle.vx
            particle.y += particle.vy
            particle.vy += 0.2
            particle.life -= 0.02
            if particle.life <= 0:
                self.particles.remove(particle)

        for ring in self.pulse_rings[:]:
            ring.radius += ring.speed
            ring.alpha -= 4
            if ring.radius > ring.max_radius or ring.alpha <= 0:
                self.pulse_rings.remove(ring)

        for comet in self.comets[:]:
            comet["x"] += comet["vx"]
            comet["y"] += comet["vy"]
            comet["life"] -= 0.015
            if comet["life"] <= 0 or comet["x"] < -200 or comet["y"] > self.height() + 200:
                self.comets.remove(comet)

        self.nebula_offset += 0.5
        if self.nebula_offset > 360:
            self.nebula_offset = 0

        self.scan_phase = (self.scan_phase + 1) % 360
        self.spawn_comet()

        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        bg = QRadialGradient(
            self.width() / 2, self.height() / 2, max(self.width(), self.height())
        )
        bg.setColorAt(0, QColor(10, 10, 10))
        bg.setColorAt(0.5, QColor(5, 5, 5))
        bg.setColorAt(1, QColor(0, 0, 0))
        painter.fillRect(self.rect(), bg)

        nebula = QRadialGradient(
            self.width() / 2 + 50 * random.uniform(-1, 1),
            self.height() / 2 + 50 * random.uniform(-1, 1),
            400,
        )
        nebula.setColorAt(0, QColor(239, 68, 68, 35))
        nebula.setColorAt(0.5, QColor(185, 28, 28, 20))
        nebula.setColorAt(1, QColor(0, 0, 0, 0))
        painter.fillRect(self.rect(), nebula)

        painter.setPen(Qt.PenStyle.NoPen)
        for star in self.stars:
            alpha = int(255 * star["brightness"])
            painter.setBrush(QColor(255, 255, 255, alpha))
            painter.drawEllipse(QRectF(star["x"], star["y"], star["size"], star["size"]))

        for particle in self.particles:
            alpha = int(255 * particle.life)
            color = QColor(particle.color)
            color.setAlpha(alpha)
            painter.setBrush(color)
            painter.drawEllipse(
                QRectF(
                    particle.x - particle.size / 2,
                    particle.y - particle.size / 2,
                    particle.size,
                    particle.size,
                )
            )

        painter.setPen(Qt.PenStyle.NoPen)
        for comet in self.comets:
            alpha = int(180 * comet["life"])
            painter.setBrush(QColor(248, 113, 113, alpha))
            painter.drawEllipse(QRectF(comet["x"], comet["y"], 3, 3))
            tail_pen = QPen(QColor(248, 113, 113, max(40, alpha // 2)), 2)
            painter.setPen(tail_pen)
            painter.drawLine(
                int(comet["x"]),
                int(comet["y"]),
                int(comet["x"] - comet["vx"] * 6),
                int(comet["y"] - comet["vy"] * 6),
            )

        painter.setPen(Qt.PenStyle.NoPen)
        for ring in self.pulse_rings:
            ring_color = QColor(ring.color)
            ring_color.setAlpha(max(0, ring.alpha))
            pen = QPen(ring_color, 2)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawEllipse(QPointF(ring.x, ring.y), ring.radius, ring.radius)

        glow = QRadialGradient(
            self.width() * 0.7, self.height() * 0.25, self.width() * 0.8
        )
        glow.setColorAt(0, QColor(248, 113, 113, 35))
        glow.setColorAt(0.7, QColor(239, 68, 68, 12))
        glow.setColorAt(1, QColor(0, 0, 0, 0))
        painter.fillRect(self.rect(), glow)


# ===============================
# STAT CARD WIDGET
# ===============================
class StatCard(QFrame):
    def __init__(self, title, value="0", unit=""):
        super().__init__()
        self.setFixedSize(170, 80)
        self.setStyleSheet("QFrame { background: transparent; }")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(6, 6, 6, 6)
        layout.setSpacing(2)

        self.value_label = QLabel(value)
        self.value_label.setFont(QFont("Segoe UI", 22, QFont.Weight.Bold))
        self.value_label.setStyleSheet("color: #ef4444; border: none;")
        self.value_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        unit_label = QLabel(unit)
        unit_label.setFont(QFont("Segoe UI", 10))
        unit_label.setStyleSheet("color: #fca5a5; border: none;")
        unit_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        title_label = QLabel(title)
        title_label.setFont(QFont("Segoe UI", 9))
        title_label.setStyleSheet("color: #fecaca; border: none;")
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        layout.addWidget(self.value_label)
        layout.addWidget(unit_label)
        layout.addWidget(title_label)

    def set_value(self, value):
        self.value_label.setText(str(value))


# ===============================
# PULSE LABEL
# ===============================
class PulseLabel(QLabel):
    def __init__(self, text="", parent=None, min_opacity=0.6, max_opacity=1.0):
        super().__init__(text, parent)
        self.opacity_effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity_effect)
        self.opacity_anim = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.opacity_anim.setDuration(1800)
        self.opacity_anim.setStartValue(min_opacity)
        self.opacity_anim.setEndValue(max_opacity)
        self.opacity_anim.setEasingCurve(QEasingCurve.Type.InOutSine)
        self.opacity_anim.setLoopCount(-1)
        self.opacity_anim.start()


# ===============================
# ANIMATED BUTTON WITH PULSE
# ===============================
class AnimatedButton(QPushButton):
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self._glow_intensity = 0
        self._base_text = text
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        self.opacity_effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity_effect)

        self.pulse_anim = QSequentialAnimationGroup(self)
        pulse_up = QPropertyAnimation(self.opacity_effect, b"opacity")
        pulse_up.setDuration(1400)
        pulse_up.setStartValue(0.82)
        pulse_up.setEndValue(1.0)
        pulse_up.setEasingCurve(QEasingCurve.Type.InOutSine)
        pulse_down = QPropertyAnimation(self.opacity_effect, b"opacity")
        pulse_down.setDuration(1400)
        pulse_down.setStartValue(1.0)
        pulse_down.setEndValue(0.82)
        pulse_down.setEasingCurve(QEasingCurve.Type.InOutSine)
        self.pulse_anim.addAnimation(pulse_up)
        self.pulse_anim.addAnimation(pulse_down)
        self.pulse_anim.setLoopCount(-1)

        self.glow_anim = QPropertyAnimation(self, b"glow_intensity")
        self.glow_anim.setDuration(600)
        self.glow_anim.setStartValue(0)
        self.glow_anim.setEndValue(30)
        self.glow_anim.setEasingCurve(QEasingCurve.Type.OutCubic)

        self.update_style()

    def start_pulse(self):
        self.pulse_anim.start()

    def stop_pulse(self):
        self.pulse_anim.stop()
        self.opacity_effect.setOpacity(1.0)

    def set_busy(self, busy: bool):
        if busy:
            self.setText("TESTING...")
        else:
            self.setText(self._base_text)

    @pyqtProperty(int)
    def glow_intensity(self):
        return self._glow_intensity

    @glow_intensity.setter
    def glow_intensity(self, value):
        self._glow_intensity = value
        self.update_style()

    def update_style(self):
        self.setStyleSheet(
            """
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #ef4444, stop:1 #dc2626);
                color: white;
                font-size: 18px;
                font-weight: bold;
                font-family: 'Segoe UI';
                padding: 18px 46px;
                border-radius: 16px;
                border: none;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #f87171, stop:1 #ef4444);
            }
            QPushButton:pressed {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #dc2626, stop:1 #b91c1c);
            }
            QPushButton:disabled {
                background: #7f1d1d;
                color: #fca5a5;
                border: 2px solid #991b1b;
            }
            """
        )

    def enterEvent(self, event):
        self.glow_anim.setDirection(QPropertyAnimation.Direction.Forward)
        self.glow_anim.start()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.glow_anim.setDirection(QPropertyAnimation.Direction.Backward)
        self.glow_anim.start()
        super().leaveEvent(event)


# ===============================
# ENHANCED PROGRESS BAR
# ===============================
class GlowProgressBar(QProgressBar):
    def __init__(self):
        super().__init__()
        self.setFixedHeight(24)
        self.setTextVisible(True)
        self.setFormat("%p%")
        self.setStyleSheet(
            """
            QProgressBar {
                background: rgba(10, 5, 5, 0.8);
                border-radius: 12px;
                color: white;
                font-weight: bold;
                font-family: 'Segoe UI';
                text-align: center;
            }
            QProgressBar::chunk {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #dc2626, stop:0.5 #ef4444, stop:1 #f87171);
                border-radius: 10px;
            }
            """
        )


# ===============================
# MAIN WINDOW
# ===============================
class NetworkOptimizerUI(GalaxyBackground):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"{APP_NAME} – {VERSION}")
        self.setFixedSize(1100, 760)
        self.last_results = None

        layout = QVBoxLayout(self)
        layout.setSpacing(0)
        layout.setContentsMargins(30, 30, 30, 30)

        content_layout = QVBoxLayout()
        content_layout.setSpacing(18)
        content_layout.setContentsMargins(10, 0, 10, 0)

        title = QLabel(APP_NAME)
        title.setFont(QFont("Segoe UI", 44, QFont.Weight.Bold))
        title.setStyleSheet("color: white; letter-spacing: 2px;")

        subtitle = PulseLabel("Smart network diagnostics with before/after results")
        subtitle.setFont(QFont("Segoe UI", 12))
        subtitle.setStyleSheet("color: #e5e7eb;")

        badges_layout = QHBoxLayout()
        badges_layout.setSpacing(10)
        badges_layout.addStretch()
        for badge_text in ("Wi-Fi", "Ethernet", "Windows 10/11", "Safe"):
            badge = QLabel(badge_text)
            badge.setFont(QFont("Segoe UI", 9, QFont.Weight.Bold))
            badge.setStyleSheet(
                "color: #fecaca; background: rgba(127, 29, 29, 0.55);"
                "padding: 4px 10px; border-radius: 10px; border: 1px solid #7f1d1d;"
            )
            badges_layout.addWidget(badge)
        badges_layout.addStretch()

        header_line = QFrame()
        header_line.setFixedHeight(2)
        header_line.setStyleSheet(
            "background: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
            "stop:0 rgba(239,68,68,0), stop:0.5 rgba(239,68,68,0.6), stop:1 rgba(239,68,68,0));"
            "border-radius: 1px;"
        )

        stats_layout = QHBoxLayout()
        stats_layout.setSpacing(20)
        self.latency_card = StatCard("Latency", "--", "ms")
        self.jitter_card = StatCard("Jitter", "--", "ms")
        self.download_card = StatCard("Download", "--", "Mbps")
        self.stability_card = StatCard("Stability", "--", "%")
        for card in (
            self.latency_card,
            self.jitter_card,
            self.download_card,
            self.stability_card,
        ):
            card.setFixedSize(170, 80)

        stats_layout.addStretch()
        stats_layout.addWidget(self.latency_card)
        stats_layout.addWidget(self.jitter_card)
        stats_layout.addWidget(self.download_card)
        stats_layout.addWidget(self.stability_card)
        stats_layout.addStretch()

        selector_layout = QHBoxLayout()
        selector_layout.setSpacing(12)
        selector_layout.addStretch()

        self.ping_selector = QComboBox()
        self.ping_selector.addItem("Auto-select")
        self.ping_selector.setEnabled(False)
        self.ping_selector.setFixedWidth(220)
        self.ping_selector.setStyleSheet(
            "QComboBox { background: rgba(15,23,42,0.65); color: #e5e7eb; "
            "padding: 6px; border-radius: 8px; }"
        )

        self.download_selector = QComboBox()
        self.download_selector.addItem("Auto-select")
        self.download_selector.setEnabled(False)
        self.download_selector.setFixedWidth(220)
        self.download_selector.setStyleSheet(
            "QComboBox { background: rgba(15,23,42,0.65); color: #e5e7eb; "
            "padding: 6px; border-radius: 8px; }"
        )

        ping_label = QLabel("Ping Target:")
        ping_label.setStyleSheet("color: #e5e7eb;")
        download_label = QLabel("Download Test:")
        download_label.setStyleSheet("color: #e5e7eb;")

        selector_layout.addWidget(ping_label)
        selector_layout.addWidget(self.ping_selector)
        selector_layout.addSpacing(12)
        selector_layout.addWidget(download_label)
        selector_layout.addWidget(self.download_selector)
        selector_layout.addStretch()

        self.run_button = AnimatedButton("OPTIMIZE NETWORK")
        self.run_button.start_pulse()
        self.run_button.clicked.connect(self.run_full_diagnostics)

        button_layout = QHBoxLayout()
        button_layout.setSpacing(18)
        button_layout.addStretch()
        button_layout.addWidget(self.run_button)
        button_layout.addStretch()

        self.progress = GlowProgressBar()
        self.progress.setFixedWidth(600)
        self.progress.setValue(0)
        self.progress.setFormat("Ready")

        self.status_label = QLabel("Ready for diagnostics")
        self.status_label.setFont(QFont("Segoe UI", 14, QFont.Weight.Bold))
        self.status_label.setStyleSheet("color: #f87171; letter-spacing: 0.5px;")

        self.substatus_label = QLabel("One click runs tests and applies safe optimizations")
        self.substatus_label.setFont(QFont("Segoe UI", 11))
        self.substatus_label.setStyleSheet("color: #fca5a5;")

        self.tip_label = PulseLabel(
            "Tip: Stay connected to your main Wi-Fi or Ethernet for best results.",
            min_opacity=0.55,
            max_opacity=0.95,
        )
        self.tip_label.setFont(QFont("Segoe UI", 10))
        self.tip_label.setStyleSheet("color: #fecaca;")

        content_layout.addWidget(title, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(subtitle, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addLayout(badges_layout)
        content_layout.addWidget(header_line)
        content_layout.addLayout(stats_layout)
        content_layout.addSpacing(10)
        content_layout.addLayout(selector_layout)
        content_layout.addSpacing(10)
        content_layout.addLayout(button_layout)
        content_layout.addWidget(self.progress, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(self.status_label, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(
            self.substatus_label, alignment=Qt.AlignmentFlag.AlignHCenter
        )
        content_layout.addWidget(self.tip_label, alignment=Qt.AlignmentFlag.AlignHCenter)

        layout.addStretch(1)
        layout.addLayout(content_layout)
        layout.addStretch(1)

    def run_full_diagnostics(self):
        self.run_button.stop_pulse()
        self.run_button.setEnabled(False)
        self.run_button.set_busy(True)
        self.add_particle_burst(self.width() // 2, self.height() // 2 + 50, 30)
        self.add_pulse_ring(self.width() // 2, self.height() // 2 + 50)

        self.progress.setValue(0)
        self.progress.setFormat("Testing... %p%")
        self.status_label.setText("Running smart diagnostics...")
        self.substatus_label.setText("Selecting best target and endpoint")

        self.worker = DiagnosticsWorker(apply_reset=True)
        self.worker.progress.connect(self.update_progress)
        self.worker.status.connect(self.update_status)
        self.worker.substatus.connect(self.update_substatus)
        self.worker.result.connect(self.show_results)
        self.worker.error.connect(self.handle_error)
        Thread(target=self.worker.run, daemon=True).start()

    def update_status(self, text):
        self.status_label.setText(text)

    def update_substatus(self, text):
        self.substatus_label.setText(text)

    def update_progress(self, value):
        self.progress.setValue(value)
        if value % 10 == 0:
            self.add_particle_burst(
                random.randint(100, self.width() - 100),
                random.randint(100, self.height() - 100),
                10,
            )
            self.add_pulse_ring(self.width() // 2, self.height() // 2 + 50)

    def show_results(self, data):
        self.last_results = data
        after = data["after"]

        self.latency_card.set_value(after.latency.average_ms)
        self.jitter_card.set_value(after.latency.jitter_ms)
        self.download_card.set_value(after.download_mbps)
        self.stability_card.set_value(after.stability)

        self.status_label.setText("Diagnostics complete")
        self.substatus_label.setText("Baseline vs after results ready")
        self.progress.setValue(100)
        self.progress.setFormat("Complete")

        self.run_button.setEnabled(True)
        self.run_button.set_busy(False)
        self.run_button.start_pulse()

        self.show_summary_dialog(data)

    def show_summary_dialog(self, data):
        baseline = data["baseline"]
        after = data["after"]
        reset_note = "Applied" if data["reset_applied"] else "Skipped (admin required)"
        nic_info = data.get("nic_info") or {}
        nic_desc = nic_info.get("description", "Unknown adapter")
        nic_speed = nic_info.get("link_speed", "Unknown")
        nic_name = nic_info.get("name", "Unknown")
        nic_mac = nic_info.get("mac", "Unknown")
        download_label = data.get("download_label", "Unavailable")
        speedtest_label = data.get("speedtest_label", "Unavailable")

        msg = QMessageBox(self)
        msg.setWindowTitle("Network Diagnostics Summary")
        msg.setText(
            f"Target: {data['target_label']}\n"
            f"Adapter: {nic_desc}\n"
            f"Interface: {nic_name}\n"
            f"MAC: {nic_mac}\n"
            f"Link Speed: {nic_speed}\n"
            f"Speedtest Server: {speedtest_label}\n"
            f"Download Source: {download_label}\n"
            f"Optimize: {reset_note}\n\n"
            f"Before:\n"
            f"• Latency: {baseline.latency.average_ms} ms\n"
            f"• Jitter: {baseline.latency.jitter_ms} ms\n"
            f"• Packet Loss: {baseline.latency.packet_loss}%\n"
            f"• Download: {baseline.download_mbps} Mbps\n"
            f"• Stability: {baseline.stability}%\n\n"
            f"After:\n"
            f"• Latency: {after.latency.average_ms} ms\n"
            f"• Jitter: {after.latency.jitter_ms} ms\n"
            f"• Packet Loss: {after.latency.packet_loss}%\n"
            f"• Download: {after.download_mbps} Mbps\n"
            f"• Stability: {after.stability}%"
        )
        msg.setIcon(QMessageBox.Icon.Information)
        msg.setStyleSheet(
            """
            QMessageBox { background: #1a1a1a; }
            QMessageBox QLabel { color: white; font-family: 'Segoe UI'; }
            QPushButton {
                background: #ef4444;
                color: white;
                padding: 8px 20px;
                border-radius: 6px;
                font-weight: bold;
            }
            QPushButton:hover { background: #f87171; }
            """
        )
        msg.exec()

    def handle_error(self, error_msg):
        self.status_label.setText("❌ Operation failed")
        self.substatus_label.setText(error_msg)
        self.progress.setFormat("Error")
        QMessageBox.critical(self, "Error", error_msg)
        self.run_button.setEnabled(True)
        self.run_button.set_busy(False)
        self.run_button.start_pulse()


# ===============================
# ENTRY POINT
# ===============================
if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = NetworkOptimizerUI()
    window.show()
    sys.exit(app.exec())
