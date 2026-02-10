import ctypes
import fnmatch
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from threading import Thread

import winreg
from PyQt6.QtCore import QObject, pyqtSignal
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFrame,
    QGraphicsDropShadowEffect,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

APP_NAME = "23 Optimizer"
VERSION = "v2.0 Pro"

HIGH_PERFORMANCE_PLAN = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
ULTIMATE_PERFORMANCE_PLAN = "e9a42b02-d5df-448d-aa00-03f14749eb61"


@dataclass
class OptimizationTask:
    name: str
    phase: str
    func_name: str
    safe: bool = True


class CommandRunner:
    @staticmethod
    def run(command: str, timeout: int = 12, hide_output: bool = True) -> bool:
        kwargs = {
            "shell": True,
            "timeout": timeout,
            "stdout": subprocess.DEVNULL if hide_output else subprocess.PIPE,
            "stderr": subprocess.DEVNULL if hide_output else subprocess.PIPE,
            "text": True,
        }
        try:
            result = subprocess.run(command, **kwargs)
            return result.returncode == 0
        except Exception:
            return False


class OptimizerWorker(QObject):
    progress = pyqtSignal(int)
    status = pyqtSignal(str)
    substatus = pyqtSignal(str)
    insight = pyqtSignal(str)
    phase = pyqtSignal(str)
    profile_ready = pyqtSignal(dict)
    done = pyqtSignal(dict)
    error = pyqtSignal(str)
    log = pyqtSignal(str)

    def __init__(self, aggressive_mode: bool, create_restore_point: bool):
        super().__init__()
        self.aggressive_mode = aggressive_mode
        self.create_restore_point = create_restore_point
        self.sys = {}
        self.ai_profile = {}
        self.stats = {
            "cleaned_mb": 0,
            "optimizations_applied": 0,
            "errors": 0,
            "skipped": 0,
            "duration": 0,
            "focus": "",
            "tier": "",
            "disk_free_gb": 0,
        }

    def run(self):
        start = time.time()
        try:
            self.status.emit("Analyzing hardware and OS telemetry")
            self.sys = self.get_system_info()
            self.ai_profile = self.build_ai_profile()
            self.stats["focus"] = ", ".join(self.ai_profile["focus"])
            self.stats["tier"] = self.ai_profile["tier"]
            self.stats["disk_free_gb"] = self.ai_profile["disk_free"]
            self.insight.emit(self.ai_profile["tagline"])
            self.profile_ready.emit(self.ai_profile)

            if self.create_restore_point:
                self.create_restore_checkpoint()

            tasks = self.build_task_pipeline()
            total = len(tasks)
            for index, task in enumerate(tasks, start=1):
                self.phase.emit(task.phase)
                self.status.emit(task.name)
                if not task.safe and not self.aggressive_mode:
                    self.stats["skipped"] += 1
                    self.substatus.emit("Skipped advanced tweak (enable Aggressive Mode)")
                    self.log.emit(f"SKIP | {task.phase} | {task.name}")
                else:
                    try:
                        getattr(self, task.func_name)()
                        self.stats["optimizations_applied"] += 1
                        self.log.emit(f"OK   | {task.phase} | {task.name}")
                    except Exception as exc:
                        self.stats["errors"] += 1
                        self.log.emit(f"ERR  | {task.phase} | {task.name} | {exc}")
                        self.substatus.emit(f"Non-blocking error: {exc}")
                self.progress.emit(int((index / total) * 100))
                time.sleep(0.09)

            self.stats["duration"] = time.time() - start
            self.done.emit(self.stats)
        except Exception as exc:
            self.error.emit(f"Critical optimizer failure: {exc}")

    def build_task_pipeline(self):
        return [
            OptimizationTask("Purge temp and residue files", "Cleanup", "clear_temp"),
            OptimizationTask("Clean browser and shader caches", "Cleanup", "clear_browser_and_shader"),
            OptimizationTask("Clear crash dumps and stale logs", "Cleanup", "clear_dumps_logs"),
            OptimizationTask("Clear recycle bin", "Cleanup", "clear_recycle_bin"),
            OptimizationTask("Purge Windows Update download cache", "Cleanup", "clear_windows_update_cache"),
            OptimizationTask("Flush DNS resolver cache", "Network", "flush_dns"),
            OptimizationTask("Reset Winsock and TCP/IP stack", "Network", "reset_network_stack"),
            OptimizationTask("Apply low-latency TCP tuning", "Network", "apply_network_latency_tweaks"),
            OptimizationTask("Optimize storage behavior (TRIM/defrag)", "Storage", "optimize_storage"),
            OptimizationTask("Apply NTFS performance profile", "Storage", "optimize_ntfs"),
            OptimizationTask("Set high/ultimate power plan", "Performance", "set_power_plan"),
            OptimizationTask("Prioritize game multimedia scheduling", "Performance", "tune_mmcss"),
            OptimizationTask("Enable HAGS + game mode where available", "Performance", "tune_game_stack"),
            OptimizationTask("Reduce visual/UI overhead", "UI", "tune_visuals"),
            OptimizationTask("Disable telemetry-heavy services", "Services", "trim_services"),
            OptimizationTask("Disable startup delay and menu lag", "UX", "tune_shell_latency"),
            OptimizationTask("Disable Nagle algorithm on active NICs", "Advanced", "disable_nagle", safe=False),
            OptimizationTask("Disable HPET dynamic tick for latency", "Advanced", "bcd_latency_profile", safe=False),
        ]

    def get_system_info(self):
        info = {"cores": os.cpu_count() or 4, "ram": 8, "gpu": "unknown", "ssd": False}
        try:
            mem_kb = ctypes.c_ulonglong()
            ctypes.windll.kernel32.GetPhysicallyInstalledSystemMemory(ctypes.byref(mem_kb))
            info["ram"] = int(mem_kb.value / (1024 * 1024))
        except Exception:
            pass

        try:
            out = subprocess.run(
                "wmic path win32_VideoController get name",
                shell=True,
                capture_output=True,
                text=True,
                timeout=8,
            ).stdout.lower()
            if "nvidia" in out:
                info["gpu"] = "nvidia"
            elif "amd" in out or "radeon" in out:
                info["gpu"] = "amd"
            elif "intel" in out:
                info["gpu"] = "intel"
        except Exception:
            pass

        try:
            out = subprocess.run(
                "wmic diskdrive get MediaType",
                shell=True,
                capture_output=True,
                text=True,
                timeout=8,
            ).stdout.lower()
            info["ssd"] = "ssd" in out or "solid state" in out
        except Exception:
            pass

        self.substatus.emit(
            f"{info['cores']}C/{info['ram']}GB | GPU: {info['gpu'].upper()} | {'SSD' if info['ssd'] else 'HDD'}"
        )
        return info

    def get_disk_free_gb(self, drive: str = "C:\\"):
        try:
            return int(shutil.disk_usage(drive).free / (1024 ** 3))
        except Exception:
            return 0

    def build_ai_profile(self):
        disk = self.get_disk_free_gb()
        cores = self.sys.get("cores", 4)
        ram = self.sys.get("ram", 8)
        ssd_bonus = 8 if self.sys.get("ssd") else 0
        tier_score = (cores * 1.1) + (ram * 0.7) + ssd_bonus
        if tier_score >= 34:
            tier = "Enthusiast"
        elif tier_score >= 22:
            tier = "Balanced"
        else:
            tier = "Essential"

        focus = []
        if disk < 20:
            focus.append("Storage Hygiene")
        if ram <= 8:
            focus.append("Memory Pressure")
        if cores <= 4:
            focus.append("CPU Scheduling")
        if self.sys.get("gpu") != "unknown":
            focus.append("Gaming Throughput")
        if not focus:
            focus.append("System Balance")

        tagline = f"Profile: {tier} • Focus: {', '.join(focus)} • Free Disk: {disk}GB"
        return {"tier": tier, "focus": focus, "tagline": tagline, "disk_free": disk}

    def _safe_delete(self, target: str, pattern: str = "*"):
        if not target or not os.path.exists(target):
            return 0
        deleted_bytes = 0
        for root, dirs, files in os.walk(target, topdown=False):
            for name in files:
                if not fnmatch.fnmatch(name, pattern):
                    continue
                p = os.path.join(root, name)
                try:
                    deleted_bytes += os.path.getsize(p)
                    os.remove(p)
                except Exception:
                    pass
            for d in dirs:
                try:
                    os.rmdir(os.path.join(root, d))
                except Exception:
                    pass
        return int(deleted_bytes / (1024 * 1024))

    def set_reg_dword(self, path: str, name: str, value: int):
        root_text, sub_key = path.split("\\", 1)
        root = getattr(winreg, root_text)
        with winreg.CreateKeyEx(root, sub_key, 0, winreg.KEY_SET_VALUE | winreg.KEY_WOW64_64KEY) as key:
            winreg.SetValueEx(key, name, 0, winreg.REG_DWORD, value)

    def create_restore_checkpoint(self):
        self.phase.emit("Safety")
        self.status.emit("Creating system restore checkpoint")
        self.substatus.emit("Rollback protection before deep optimizations")
        CommandRunner.run(
            "powershell -Command \"Checkpoint-Computer -Description '23 Optimizer Pro' -RestorePointType 'MODIFY_SETTINGS'\"",
            timeout=45,
        )

    def clear_temp(self):
        self.substatus.emit("Removing temp residue from user/system paths")
        paths = [
            os.environ.get("TEMP", ""),
            os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "Temp"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Temp"),
            r"C:\Windows\Prefetch",
        ]
        for p in paths:
            self.stats["cleaned_mb"] += self._safe_delete(p)

    def clear_browser_and_shader(self):
        self.substatus.emit("Purging browser code caches and DirectX shader cache")
        local = os.environ.get("LOCALAPPDATA", "")
        paths = [
            os.path.join(local, "Google", "Chrome", "User Data", "Default", "Cache"),
            os.path.join(local, "Google", "Chrome", "User Data", "Default", "Code Cache"),
            os.path.join(local, "Microsoft", "Edge", "User Data", "Default", "Cache"),
            os.path.join(local, "Microsoft", "Edge", "User Data", "Default", "Code Cache"),
            os.path.join(local, "D3DSCache"),
            os.path.join(local, "NVIDIA", "DXCache"),
            os.path.join(local, "NVIDIA", "GLCache"),
            os.path.join(local, "AMD", "DxCache"),
        ]
        for p in paths:
            self.stats["cleaned_mb"] += self._safe_delete(p)

    def clear_dumps_logs(self):
        self.substatus.emit("Cleaning dumps, WER reports, thumbnails and stale logs")
        paths = [
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "CrashDumps"),
            r"C:\Windows\Minidump",
            r"C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
            r"C:\Windows\Logs\CBS",
            r"C:\Windows\Logs\DISM",
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Windows", "Explorer"),
        ]
        for p in paths:
            self.stats["cleaned_mb"] += self._safe_delete(p)

    def clear_recycle_bin(self):
        self.substatus.emit("Emptying recycle bin")
        CommandRunner.run("PowerShell.exe -Command Clear-RecycleBin -Force -ErrorAction SilentlyContinue")

    def clear_windows_update_cache(self):
        self.substatus.emit("Stopping update services and deleting old update payloads")
        for svc in ["wuauserv", "bits", "dosvc"]:
            CommandRunner.run(f"net stop {svc}", timeout=10)
        self.stats["cleaned_mb"] += self._safe_delete(r"C:\Windows\SoftwareDistribution\Download")
        self.stats["cleaned_mb"] += self._safe_delete(r"C:\Windows\SoftwareDistribution\DeliveryOptimization\Cache")
        for svc in ["wuauserv", "bits", "dosvc"]:
            CommandRunner.run(f"net start {svc}", timeout=10)

    def flush_dns(self):
        self.substatus.emit("Flushing DNS resolver")
        CommandRunner.run("ipconfig /flushdns")

    def reset_network_stack(self):
        self.substatus.emit("Rebuilding Winsock and TCP defaults")
        for cmd in [
            "netsh winsock reset",
            "netsh int ip reset",
            "netsh int tcp set global autotuninglevel=normal",
            "netsh int tcp set global rss=enabled",
            "netsh int tcp set global chimney=disabled",
        ]:
            CommandRunner.run(cmd)

    def apply_network_latency_tweaks(self):
        self.substatus.emit("Applying DNS cache and network throttling tweaks")
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters", "MaxCacheTtl", 86400)
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile", "NetworkThrottlingIndex", 4294967295)

    def optimize_storage(self):
        if self.sys.get("ssd"):
            self.substatus.emit("SSD profile: force TRIM + retrim optimize")
            CommandRunner.run("fsutil behavior set DisableDeleteNotify 0")
            CommandRunner.run("defrag C: /L /O", timeout=90)
        else:
            self.substatus.emit("HDD profile: sequential defrag pass")
            CommandRunner.run("defrag C: /U /V", timeout=150)

    def optimize_ntfs(self):
        self.substatus.emit("Setting NTFS metadata tuning flags")
        for cmd in [
            "fsutil behavior set memoryusage 2",
            "fsutil behavior set mftzone 2",
            "fsutil behavior set disablelastaccess 1",
        ]:
            CommandRunner.run(cmd)

    def set_power_plan(self):
        self.substatus.emit("Switching to highest available performance plan")
        if not CommandRunner.run(f"powercfg -setactive {ULTIMATE_PERFORMANCE_PLAN}"):
            CommandRunner.run(f"powercfg -setactive {HIGH_PERFORMANCE_PLAN}")

    def tune_mmcss(self):
        self.substatus.emit("Prioritizing game/RT workloads in MMCSS")
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile", "SystemResponsiveness", 0)
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games", "GPU Priority", 8)
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games", "Priority", 6)
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games", "Scheduling Category", 2)

    def tune_game_stack(self):
        self.substatus.emit("Enabling Game Mode + hardware accelerated scheduling")
        self.set_reg_dword("HKEY_CURRENT_USER\\Software\\Microsoft\\GameBar", "AutoGameModeEnabled", 1)
        self.set_reg_dword("HKEY_CURRENT_USER\\System\\GameConfigStore", "GameDVR_Enabled", 0)
        self.set_reg_dword("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers", "HwSchMode", 2)

    def tune_visuals(self):
        self.substatus.emit("Reducing compositor overhead and non-essential animations")
        self.set_reg_dword("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects", "VisualFXSetting", 2)
        CommandRunner.run(r'reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f')
        CommandRunner.run(r'reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f')

    def trim_services(self):
        self.substatus.emit("Disabling telemetry-oriented services")
        for svc in ["DiagTrack", "dmwappushservice"]:
            CommandRunner.run(f"sc config {svc} start=disabled")
            CommandRunner.run(f"sc stop {svc}")

    def tune_shell_latency(self):
        self.substatus.emit("Removing UX delay, tips, and suggestion noise")
        CommandRunner.run(r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f')
        CommandRunner.run(r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f')

    def disable_nagle(self):
        self.substatus.emit("Disabling Nagle algorithm on NIC interfaces")
        interfaces_key = r"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, interfaces_key, 0, winreg.KEY_READ | winreg.KEY_WRITE) as root:
            i = 0
            while True:
                try:
                    sub = winreg.EnumKey(root, i)
                except OSError:
                    break
                i += 1
                path = f"HKEY_LOCAL_MACHINE\\{interfaces_key}\\{sub}"
                try:
                    self.set_reg_dword(path, "TcpAckFrequency", 1)
                    self.set_reg_dword(path, "TCPNoDelay", 1)
                except Exception:
                    pass

    def bcd_latency_profile(self):
        self.substatus.emit("Applying boot-level latency profile")
        CommandRunner.run("bcdedit /set useplatformclock no")
        CommandRunner.run("bcdedit /set disabledynamictick yes")


class StatCard(QFrame):
    def __init__(self, title: str, value: str):
        super().__init__()
        self.setObjectName("StatCard")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 10, 14, 10)
        self.title = QLabel(title)
        self.title.setObjectName("CardTitle")
        self.value = QLabel(value)
        self.value.setObjectName("CardValue")
        layout.addWidget(self.title)
        layout.addWidget(self.value)

    def set_value(self, text: str):
        self.value.setText(text)


class OptimizerWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.worker = None
        self._build_ui()
        self.setWindowTitle(f"{APP_NAME} {VERSION}")

    def _build_ui(self):
        self.setMinimumSize(980, 700)
        root = QVBoxLayout(self)
        root.setContentsMargins(22, 22, 22, 22)
        root.setSpacing(16)

        hero = QFrame()
        hero.setObjectName("Hero")
        hero_layout = QVBoxLayout(hero)
        hero_layout.setContentsMargins(20, 18, 20, 18)

        title = QLabel(f"{APP_NAME} • {VERSION}")
        title.setObjectName("Title")
        subtitle = QLabel("One-click cleanup + deep FPS/latency optimization pipeline")
        subtitle.setObjectName("Subtitle")
        self.insight = QLabel("Ready. Click Optimize Now to deploy full stack tuning.")
        self.insight.setObjectName("Insight")

        hero_layout.addWidget(title)
        hero_layout.addWidget(subtitle)
        hero_layout.addWidget(self.insight)
        root.addWidget(hero)

        cards_row = QHBoxLayout()
        self.card_tier = StatCard("AI Tier", "--")
        self.card_focus = StatCard("Focus", "--")
        self.card_disk = StatCard("Free Disk", "--")
        for card in [self.card_tier, self.card_focus, self.card_disk]:
            shadow = QGraphicsDropShadowEffect(blurRadius=22, xOffset=0, yOffset=4, color=QColor(0, 0, 0, 60))
            card.setGraphicsEffect(shadow)
            cards_row.addWidget(card)
        root.addLayout(cards_row)

        controls = QFrame()
        controls_layout = QHBoxLayout(controls)
        controls_layout.setContentsMargins(12, 10, 12, 10)

        self.aggressive = QCheckBox("Aggressive Mode (advanced latency tweaks)")
        self.aggressive.setChecked(True)
        self.restore = QCheckBox("Create restore point before optimization")
        self.restore.setChecked(True)
        controls_layout.addWidget(self.aggressive)
        controls_layout.addWidget(self.restore)
        controls_layout.addStretch()
        root.addWidget(controls)

        self.phase = QLabel("Phase: Idle")
        self.phase.setObjectName("Phase")
        self.status = QLabel("Status: Waiting")
        self.substatus = QLabel("No actions running")
        self.progress = QProgressBar()
        self.progress.setRange(0, 100)
        self.progress.setValue(0)

        root.addWidget(self.phase)
        root.addWidget(self.status)
        root.addWidget(self.substatus)
        root.addWidget(self.progress)

        self.log_output = QTextEdit()
        self.log_output.setReadOnly(True)
        self.log_output.setMinimumHeight(240)
        root.addWidget(self.log_output)

        action_row = QHBoxLayout()
        self.optimize_btn = QPushButton("Optimize Now")
        self.optimize_btn.clicked.connect(self.start_optimization)
        self.optimize_btn.setObjectName("OptimizeBtn")
        self.exit_btn = QPushButton("Exit")
        self.exit_btn.clicked.connect(self.close)
        action_row.addWidget(self.optimize_btn)
        action_row.addWidget(self.exit_btn)
        root.addLayout(action_row)

        self.setStyleSheet(
            """
            QWidget { background: #0b1220; color: #e6edf3; font-family: Segoe UI; font-size: 13px; }
            #Hero { background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #13233f, stop:1 #1d3b72); border-radius: 14px; }
            #Title { font-size: 28px; font-weight: 700; }
            #Subtitle { color: #b9c6d6; font-size: 14px; }
            #Insight { color: #8ee3ff; font-size: 13px; }
            #StatCard { background: #141d2e; border: 1px solid #25324f; border-radius: 12px; }
            #CardTitle { color: #9db1c8; font-size: 12px; text-transform: uppercase; }
            #CardValue { color: #f8fbff; font-size: 18px; font-weight: 600; }
            #Phase { color: #89b4ff; font-weight: 600; }
            QProgressBar { background: #182238; border: 1px solid #2b3f67; border-radius: 8px; height: 20px; text-align: center; }
            QProgressBar::chunk { background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #39d98a, stop:1 #3aa0ff); border-radius: 7px; }
            QTextEdit { background: #0d1628; border: 1px solid #283a5e; border-radius: 10px; }
            QCheckBox { color: #d4e3f4; }
            QPushButton { background: #1f2f4d; border: 1px solid #3c5c93; border-radius: 10px; padding: 10px 16px; }
            QPushButton:hover { background: #29406a; }
            #OptimizeBtn { background: #1f6feb; border-color: #7ab8ff; font-weight: 700; }
            #OptimizeBtn:hover { background: #2a7ef2; }
            """
        )

    def start_optimization(self):
        self.optimize_btn.setEnabled(False)
        self.log_output.clear()
        self.progress.setValue(0)
        self.append_log("Starting full optimization pipeline...")

        self.worker = OptimizerWorker(self.aggressive.isChecked(), self.restore.isChecked())
        self.worker_thread = Thread(target=self.worker.run, daemon=True)

        self.worker.progress.connect(self.progress.setValue)
        self.worker.status.connect(lambda s: self.status.setText(f"Status: {s}"))
        self.worker.substatus.connect(self.substatus.setText)
        self.worker.insight.connect(self.insight.setText)
        self.worker.phase.connect(lambda p: self.phase.setText(f"Phase: {p}"))
        self.worker.profile_ready.connect(self.update_profile)
        self.worker.done.connect(self.on_done)
        self.worker.error.connect(self.on_error)
        self.worker.log.connect(self.append_log)

        self.worker_thread.start()

    def append_log(self, text: str):
        ts = datetime.now().strftime("%H:%M:%S")
        self.log_output.append(f"[{ts}] {text}")

    def update_profile(self, data: dict):
        self.card_tier.set_value(data.get("tier", "--"))
        self.card_focus.set_value(", ".join(data.get("focus", []))[:34] or "--")
        self.card_disk.set_value(f"{data.get('disk_free', 0)} GB")

    def on_done(self, stats: dict):
        self.optimize_btn.setEnabled(True)
        self.progress.setValue(100)
        self.append_log("Optimization completed.")
        summary = (
            f"Completed in {int(stats['duration'])}s\n"
            f"Optimizations Applied: {stats['optimizations_applied']}\n"
            f"Skipped: {stats['skipped']}\n"
            f"Errors: {stats['errors']}\n"
            f"Estimated cleaned space: {stats['cleaned_mb']} MB\n"
            f"Profile Tier: {stats['tier']}\n"
            f"Focus: {stats['focus']}"
        )
        QMessageBox.information(self, "23 Optimizer - Completed", summary)

    def on_error(self, message: str):
        self.optimize_btn.setEnabled(True)
        self.append_log(message)
        QMessageBox.critical(self, "23 Optimizer - Error", message)


def is_admin():
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def relaunch_as_admin():
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, os.path.abspath(__file__), None, 1)


def main():
    if os.name != "nt":
        print("This optimizer currently targets Windows only.")
        return

    if not is_admin():
        app = QApplication(sys.argv)
        response = QMessageBox.question(
            None,
            "Administrator Permission Required",
            "23 Optimizer needs admin rights for system tuning. Relaunch as administrator now?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if response == QMessageBox.StandardButton.Yes:
            relaunch_as_admin()
        return

    app = QApplication(sys.argv)
    app.setFont(QFont("Segoe UI", 10))
    window = OptimizerWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
