import sys, os, ctypes, subprocess, shutil, random, time, winreg, math
from threading import Thread
from datetime import datetime

from PyQt6.QtCore import (
    Qt, QTimer, QRectF, pyqtSignal, QObject,
    QPropertyAnimation, QEasingCurve, pyqtProperty, QSequentialAnimationGroup,
    QParallelAnimationGroup, QPointF
)
from PyQt6.QtGui import QColor, QPainter, QFont, QRadialGradient, QPen, QLinearGradient
from PyQt6.QtWidgets import (
    QApplication, QWidget, QPushButton, QLabel,
    QVBoxLayout, QProgressBar, QMessageBox, QGraphicsOpacityEffect,
    QHBoxLayout, QFrame
)

APP_NAME = "23 Optimizer"
VERSION = "v1.4"

SAFE_MODE = True
CREATE_RESTORE_POINT = True

# ===============================
# ADMIN CHECK
# ===============================
def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

# ===============================
# SAFE REGISTRY OPERATIONS
# ===============================
class SafeRegistry:
    @staticmethod
    def set_value(key_path, value_name, value, value_type=winreg.REG_DWORD):
        """Safely set registry value with error handling"""
        try:
            parts = key_path.split('\\', 1)
            root_key = getattr(winreg, parts[0])
            sub_key = parts[1]
            
            key = winreg.OpenKey(root_key, sub_key, 0, winreg.KEY_SET_VALUE | winreg.KEY_WOW64_64KEY)
            winreg.SetValueEx(key, value_name, 0, value_type, value)
            winreg.CloseKey(key)
            return True
        except Exception as e:
            print(f"Registry error: {e}")
            return False
    
    @staticmethod
    def backup_value(key_path, value_name):
        """Backup a registry value before modifying"""
        try:
            parts = key_path.split('\\', 1)
            root_key = getattr(winreg, parts[0])
            sub_key = parts[1]
            
            key = winreg.OpenKey(root_key, sub_key, 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
            value, _ = winreg.QueryValueEx(key, value_name)
            winreg.CloseKey(key)
            return value
        except:
            return None

# ===============================
# OPTIMIZER WORKER
# ===============================
class OptimizerWorker(QObject):
    progress = pyqtSignal(int)
    status = pyqtSignal(str)
    substatus = pyqtSignal(str)
    insight = pyqtSignal(str)
    done = pyqtSignal(dict)
    error = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.stats = {
            'cleaned_mb': 0,
            'optimizations_applied': 0,
            'errors': 0,
            'skipped': 0,
            'duration': 0,
            'focus': '',
            'tier': ''
        }
        self.ai_profile = {}

    def run(self):
        start_time = time.time()
        
        try:
            # Get system info
            self.status.emit("Analyzing system...")
            self.substatus.emit("Detecting hardware configuration")
            self.sys = self.get_system_info()
            time.sleep(0.5)

            self.status.emit("AI planning optimization...")
            self.substatus.emit("Building adaptive optimization profile")
            self.ai_profile = self.build_ai_profile()
            self.stats['focus'] = ", ".join(self.ai_profile["focus"])
            self.stats['tier'] = self.ai_profile["tier"]
            self.insight.emit(self.ai_profile["tagline"])
            time.sleep(0.4)
            
            # Create restore point if enabled
            if CREATE_RESTORE_POINT and SAFE_MODE:
                self.create_restore_point()
            
            # Define optimization steps
            steps = self._get_optimization_steps()
            
            total = len(steps)
            for i, (step_func, step_name, is_safe) in enumerate(steps):
                if SAFE_MODE and not is_safe:
                    self.substatus.emit(f"Skipped (advanced): {step_name}")
                    self.stats['skipped'] += 1
                    time.sleep(0.1)
                else:
                    try:
                        self.status.emit(step_name)
                        step_func()
                        self.stats['optimizations_applied'] += 1
                    except Exception as e:
                        self.stats['errors'] += 1
                        self.substatus.emit(f"Error in {step_name}: {str(e)}")
                        time.sleep(0.3)
                
                self.progress.emit(int(((i + 1) / total) * 100))
                time.sleep(0.15)
            
            self.stats['duration'] = time.time() - start_time
            self.done.emit(self.stats)
            
        except Exception as e:
            self.error.emit(f"Critical error: {str(e)}")

    def _get_optimization_steps(self):
        """Returns list of (function, name, is_safe) tuples"""
        steps = [
            # AI-guided cleanup
            (self.clear_crash_dumps, "Clearing crash dumps", True),
            (self.clear_shader_cache, "Clearing shader cache", True),
            (self.clear_browser_cache, "Clearing browser caches", True),
            (self.clear_spooler_cache, "Clearing print spooler cache", True),
            (self.clear_cbs_logs, "Clearing system servicing logs", True),
            (self.clear_dism_logs, "Clearing DISM logs", True),

            # Cleanup - All Safe
            (self.clear_temp, "Cleaning temporary files", True),
            (self.clear_prefetch, "Cleaning prefetch cache", True),
            (self.clear_recycle_bin, "Emptying Recycle Bin", True),
            (self.clear_error_reports, "Clearing error reports", True),
            (self.clear_windows_logs, "Clearing Windows logs", True),
            (self.clear_thumbnail_cache, "Clearing thumbnail cache", True),
            (self.clear_delivery_optimization_cache, "Clearing delivery optimization cache", True),
            
            # Network - Safe
            (self.flush_dns, "Flushing DNS cache", True),
            (self.optimize_dns, "Optimizing DNS settings", True),
            (self.reset_network, "Resetting network stack", True),
            
            # Disk - Safe (HDD/SSD aware)
            (self.optimize_disk, "Optimizing storage", True),
            (self.disable_last_access, "Disabling last access time", True),
            (self.optimize_ntfs, "Optimizing NTFS", True),
            
            # System - Safe
            (self.optimize_visuals, "Optimizing visual effects", True),
            (self.optimize_explorer, "Optimizing File Explorer", True),
            (self.optimize_startup, "Optimizing startup", True),
            (self.reduce_menu_delay, "Reducing menu delays", True),
            (self.optimize_notifications, "Reducing Windows suggestions", True),
            
            # Services - Safe
            (self.disable_telemetry, "Disabling telemetry", True),
            (self.optimize_windows_search, "Optimizing Windows Search", True),
            (self.disable_unnecessary_services, "Optimizing services", True),
            
            # Performance - Mostly Safe
            (self.optimize_power_plan, "Setting high performance plan", True),
            (self.optimize_system_responsiveness, "Improving responsiveness", True),
            (self.optimize_game_mode, "Enabling Game Mode", True),
            (self.disable_game_dvr, "Disabling Game DVR", True),
]
        return steps
    # ===============================
    # SYSTEM INFO
    # ===============================
    def get_system_info(self):
        info = {}
        
        # CPU cores
        info["cores"] = os.cpu_count() or 4
        
        # RAM
        try:
            mem = ctypes.c_ulonglong()
            ctypes.windll.kernel32.GetPhysicallyInstalledSystemMemory(ctypes.byref(mem))
            info["ram"] = int(mem.value / (1024 * 1024))  # Convert to GB
        except:
            info["ram"] = 8
        
        # GPU detection
        try:
            gpu_out = subprocess.run(
                "wmic path win32_VideoController get name",
                shell=True, capture_output=True, text=True, timeout=5
            ).stdout.lower()
            
            if "nvidia" in gpu_out:
                info["gpu"] = "nvidia"
            elif "amd" in gpu_out or "radeon" in gpu_out:
                info["gpu"] = "amd"
            elif "intel" in gpu_out:
                info["gpu"] = "intel"
            else:
                info["gpu"] = "unknown"
        except:
            info["gpu"] = "unknown"
        
        # Disk type detection (SSD vs HDD)
        try:
            drive_out = subprocess.run(
                "wmic diskdrive get MediaType",
                shell=True, capture_output=True, text=True, timeout=5
            ).stdout.lower()
            
            info["ssd"] = "ssd" in drive_out or "solid state" in drive_out
        except:
            # Fallback: check if TRIM is enabled (SSD indicator)
            try:
                trim_out = subprocess.run(
                    "fsutil behavior query DisableDeleteNotify",
                    shell=True, capture_output=True, text=True, timeout=5
                ).stdout
                info["ssd"] = "0" in trim_out
            except:
                info["ssd"] = False
        
        self.substatus.emit(f"{info['cores']} cores | {info['ram']}GB RAM | {info['gpu'].upper()} GPU | {'SSD' if info['ssd'] else 'HDD'}")
        return info

    def get_disk_free_gb(self, drive="C:\\"):
        try:
            usage = shutil.disk_usage(drive)
            return int(usage.free / (1024 ** 3))
        except:
            return 0

    def build_ai_profile(self):
        disk_free = self.get_disk_free_gb()
        disk_low = disk_free < 12
        cores = self.sys.get("cores", 4)
        ram = self.sys.get("ram", 8)
        gpu = self.sys.get("gpu", "unknown")

        tier_score = (cores * 1.2) + (ram / 2) + (8 if self.sys.get("ssd") else 0)
        if tier_score >= 26:
            tier = "Elite"
        elif tier_score >= 16:
            tier = "Balanced"
        else:
            tier = "Lite"

        focus = []
        if disk_low:
            focus.append("Storage")
        if ram <= 8:
            focus.append("Memory")
        if cores <= 4:
            focus.append("Responsiveness")
        if gpu != "unknown":
            focus.append("Graphics")
        if not focus:
            focus.append("System Balance")

        tagline = f"AI Focus: {', '.join(focus)} • Tier: {tier} • Free Space: {disk_free}GB"
        return {
            "tier": tier,
            "focus": focus,
            "tagline": tagline,
            "disk_low": disk_low,
            "disk_free": disk_free
        }

    # ===============================
    # SYSTEM RESTORE
    # ===============================
    def create_restore_point(self):
        self.status.emit("Creating restore point...")
        self.substatus.emit("Safety backup before optimization")
        try:
            subprocess.run(
                'powershell -Command "Checkpoint-Computer -Description \'23 Optimizer Backup\' -RestorePointType \'MODIFY_SETTINGS\'"',
                shell=True, timeout=30, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            time.sleep(1)
        except:
            self.substatus.emit("Restore point creation skipped")

    # ===============================
    # CLEANUP OPERATIONS
    # ===============================
    def clear_temp(self):
        self.substatus.emit("Removing temporary files")
        size = 0
        temp_paths = [
            os.environ.get("TEMP", ""),
            os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "Temp"),
        ]
        for path in temp_paths:
            size += self._safe_delete(path)
        self.stats['cleaned_mb'] += size

    def clear_prefetch(self):
        self.substatus.emit("Cleaning prefetch to improve boot time")
        size = self._safe_delete(r"C:\Windows\Prefetch", "*.pf")
        self.stats['cleaned_mb'] += size

    def clear_recycle_bin(self):
        self.substatus.emit("Emptying all recycle bins")
        subprocess.run(
            "PowerShell.exe -Command Clear-RecycleBin -Force -ErrorAction SilentlyContinue",
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10
        )

    def clear_error_reports(self):
        self.substatus.emit("Removing error report files")
        size = self._safe_delete(r"C:\ProgramData\Microsoft\Windows\WER\ReportQueue")
        self.stats['cleaned_mb'] += size

    def clear_windows_logs(self):
        self.substatus.emit("Clearing Windows event logs")
        try:
            subprocess.run(
                'for /F "tokens=*" %1 in (\'wevtutil.exe el\') DO wevtutil.exe cl "%1"',
                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10
            )
        except:
            pass

    def clear_thumbnail_cache(self):
        self.substatus.emit("Clearing thumbnail cache")
        thumb_path = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Windows", "Explorer")
        size = self._safe_delete(thumb_path, "thumbcache_*.db")
        self.stats['cleaned_mb'] += size

    def clear_spooler_cache(self):
        self.substatus.emit("Clearing print spooler cache")
        try:
            subprocess.run("net stop spooler", shell=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=10)
        except:
            pass
        self.stats['cleaned_mb'] += self._safe_delete(r"C:\Windows\System32\spool\PRINTERS")
        try:
            subprocess.run("net start spooler", shell=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=10)
        except:
            pass

    def clear_cbs_logs(self):
        self.substatus.emit("Clearing component servicing logs")
        self.stats['cleaned_mb'] += self._safe_delete(r"C:\Windows\Logs\CBS")

    def clear_dism_logs(self):
        self.substatus.emit("Clearing DISM logs")
        self.stats['cleaned_mb'] += self._safe_delete(r"C:\Windows\Logs\DISM")

    def clear_crash_dumps(self):
        self.substatus.emit("Removing crash dump files")
        paths = [
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "CrashDumps"),
            r"C:\Windows\Minidump"
        ]
        size = 0
        for path in paths:
            size += self._safe_delete(path)
        self.stats['cleaned_mb'] += size

    def clear_shader_cache(self):
        self.substatus.emit("Removing shader cache")
        paths = [
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "D3DSCache"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "NVIDIA", "GLCache"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "AMD", "DxCache")
        ]
        size = 0
        for path in paths:
            size += self._safe_delete(path)
        self.stats['cleaned_mb'] += size

    def clear_browser_cache(self):
        self.substatus.emit("Refreshing browser caches")
        local = os.environ.get("LOCALAPPDATA", "")
        paths = [
            os.path.join(local, "Google", "Chrome", "User Data", "Default", "Cache"),
            os.path.join(local, "Google", "Chrome", "User Data", "Default", "Code Cache"),
            os.path.join(local, "Microsoft", "Edge", "User Data", "Default", "Cache"),
            os.path.join(local, "Microsoft", "Edge", "User Data", "Default", "Code Cache")
        ]
        size = 0
        for path in paths:
            size += self._safe_delete(path)
        self.stats['cleaned_mb'] += size

    def clear_delivery_optimization_cache(self):
        self.substatus.emit("Clearing delivery optimization cache")
        path = r"C:\Windows\SoftwareDistribution\DeliveryOptimization\Cache"
        self.stats['cleaned_mb'] += self._safe_delete(path)


    # ===============================
    # NETWORK OPTIMIZATIONS
    # ===============================
    def flush_dns(self):
        self.substatus.emit("Clearing DNS resolver cache")
        subprocess.run("ipconfig /flushdns", shell=True,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

    def optimize_dns(self):
        self.substatus.emit("Configuring DNS cache settings")
        subprocess.run(
            'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters" '
            '/v MaxCacheTtl /t REG_DWORD /d 86400 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def reset_network(self):
        self.substatus.emit("Resetting network stack")
        cmds = [
            "netsh winsock reset",
            "netsh int ip reset",
            "netsh int tcp set global autotuninglevel=normal",
        ]
        for cmd in cmds:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, 
                         stderr=subprocess.DEVNULL, timeout=5)

    # ===============================
    # DISK OPTIMIZATIONS (SSD/HDD Aware)
    # ===============================
    def optimize_disk(self):
        if self.sys["ssd"]:
            self.substatus.emit("Optimizing SSD (TRIM enabled)")
            # Enable TRIM
            subprocess.run(
                "fsutil behavior set DisableDeleteNotify 0",
                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
            )
            # Optimize SSD
            subprocess.run(
                "defrag C: /L /O",
                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30
            )
        else:
            self.substatus.emit("Optimizing HDD (defragmentation)")
            # Quick defrag for HDD
            subprocess.run(
                "defrag C: /U /V",
                shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60
            )

    def disable_last_access(self):
        self.substatus.emit("Disabling last access time tracking")
        subprocess.run(
            "fsutil behavior set disablelastaccess 1",
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def optimize_ntfs(self):
        self.substatus.emit("Optimizing NTFS performance")
        cmds = [
            "fsutil behavior set memoryusage 2",
            "fsutil behavior set mftzone 2",
        ]
        for cmd in cmds:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, 
                         stderr=subprocess.DEVNULL, timeout=5)

    # ===============================
    # VISUAL & UI OPTIMIZATIONS
    # ===============================
    def optimize_visuals(self):
        self.substatus.emit("Adjusting visual effects for performance")
        subprocess.run(
            r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" '
            r'/v VisualFXSetting /t REG_DWORD /d 2 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def optimize_explorer(self):
        self.substatus.emit("Optimizing File Explorer")
        cmds = [
            r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f',
            r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f',
        ]
        for cmd in cmds:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, 
                         stderr=subprocess.DEVNULL, timeout=5)

    def optimize_startup(self):
        self.substatus.emit("Reducing startup delays")
        subprocess.run(
            r'reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" '
            r'/v StartupDelayInMSec /t REG_DWORD /d 0 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def reduce_menu_delay(self):
        self.substatus.emit("Reducing menu show delay")
        subprocess.run(
            r'reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def optimize_notifications(self):
        self.substatus.emit("Reducing Windows tips and suggestions")
        cmds = [
            r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f',
            r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f',
            r'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f'
        ]
        for cmd in cmds:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, timeout=5)

    # ===============================
    # SERVICES & TELEMETRY
    # ===============================
    def disable_telemetry(self):
        self.substatus.emit("Disabling telemetry and diagnostics")
        cmds = [
            r'reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f',
            r'reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f',
        ]
        for cmd in cmds:
            subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, 
                         stderr=subprocess.DEVNULL, timeout=5)
        
        # Disable DiagTrack service
        subprocess.run("sc config DiagTrack start=disabled",
                      shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

    def optimize_windows_search(self):
        self.substatus.emit("Optimizing Windows Search indexing")
        subprocess.run(
            r'reg add "HKLM\SOFTWARE\Microsoft\Windows Search" /v SetupCompletedSuccessfully /t REG_DWORD /d 0 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def disable_unnecessary_services(self):
        self.substatus.emit("Disabling unnecessary background services")
        # Only disable truly safe services
        safe_services = ["DiagTrack", "dmwappushservice"]
        for svc in safe_services:
            subprocess.run(f"sc config {svc} start=disabled",
                         shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

    # ===============================
    # PERFORMANCE OPTIMIZATIONS
    # ===============================
    def optimize_power_plan(self):
        self.substatus.emit("Setting high performance power plan")
        subprocess.run(
            "powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def optimize_system_responsiveness(self):
        self.substatus.emit("Improving system responsiveness")
        subprocess.run(
            r'reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" '
            r'/v SystemResponsiveness /t REG_DWORD /d 10 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def optimize_game_mode(self):
        self.substatus.emit("Enabling Windows Game Mode")
        subprocess.run(
            r'reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    def disable_game_dvr(self):
        self.substatus.emit("Disabling Game DVR for better FPS")
        subprocess.run(
            r'reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f',
            shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
        )

    # ===============================
    # SAFE DELETE HELPER
    # ===============================
    def _safe_delete(self, path, pattern="*"):
        """Safely delete files with size tracking"""
        if not path or not os.path.exists(path):
            return 0
        
        size_freed = 0
        try:
            for item in os.listdir(path):
                if pattern == "*" or item.endswith(pattern.replace("*", "")):
                    try:
                        item_path = os.path.join(path, item)
                        if os.path.isfile(item_path):
                            size = os.path.getsize(item_path) / (1024 * 1024)  # MB
                            os.unlink(item_path)
                            size_freed += size
                        elif os.path.isdir(item_path):
                            shutil.rmtree(item_path, ignore_errors=True)
                    except:
                        pass
        except:
            pass
        
        return size_freed

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
        
        # Create star field with twinkle
        for _ in range(200):
            self.stars.append({
                'x': random.randint(0, 1200),
                'y': random.randint(0, 800),
                'size': random.uniform(1, 3),
                'speed': random.uniform(0.3, 1.5),
                'brightness': random.uniform(0.3, 1.0),
                'twinkle_speed': random.uniform(0.02, 0.08),
                'twinkle_phase': random.uniform(0, 6.28)
            })
        
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.animate)
        self.timer.start(30)

    def add_particle_burst(self, x, y, count=20):
        """Add particle burst effect"""
        colors = [QColor(239, 68, 68), QColor(220, 38, 38), QColor(248, 113, 113)]
        for _ in range(count):
            angle = random.uniform(0, 2 * 3.14159)
            speed = random.uniform(2, 6)
            self.particles.append(Particle(
                x, y,
                speed * random.uniform(-1, 1),
                speed * random.uniform(-1, 1),
                random.uniform(2, 5),
                random.choice(colors)
            ))

    def add_pulse_ring(self, x, y, color=QColor(248, 113, 113)):
        self.pulse_rings.append(PulseRing(x, y, color=color))

    def spawn_comet(self):
        if random.random() < 0.03:
            self.comets.append({
                'x': random.randint(0, self.width()),
                'y': random.randint(-200, 0),
                'vx': random.uniform(-3, -1),
                'vy': random.uniform(4, 7),
                'life': 1.0
            })

    def animate(self):
        # Animate stars with twinkle
        for star in self.stars:
            star['y'] += star['speed']
            if star['y'] > self.height():
                star['x'] = random.randint(0, self.width())
                star['y'] = 0
                star['brightness'] = random.uniform(0.3, 1.0)
            
            # Twinkle effect
            star['twinkle_phase'] += star['twinkle_speed']
            star['brightness'] = 0.4 + 0.6 * abs(math.sin(star['twinkle_phase']))
        
        # Animate particles
        for particle in self.particles[:]:
            particle.x += particle.vx
            particle.y += particle.vy
            particle.vy += 0.2  # Gravity
            particle.life -= 0.02
            if particle.life <= 0:
                self.particles.remove(particle)

        for ring in self.pulse_rings[:]:
            ring.radius += ring.speed
            ring.alpha -= 4
            if ring.radius > ring.max_radius or ring.alpha <= 0:
                self.pulse_rings.remove(ring)

        for comet in self.comets[:]:
            comet['x'] += comet['vx']
            comet['y'] += comet['vy']
            comet['life'] -= 0.015
            if comet['life'] <= 0 or comet['x'] < -200 or comet['y'] > self.height() + 200:
                self.comets.remove(comet)

        # Nebula drift
        self.nebula_offset += 0.5
        if self.nebula_offset > 360:
            self.nebula_offset = 0

        self.scan_phase = (self.scan_phase + 1) % 360
        self.spawn_comet()

        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Pure black background
        bg = QRadialGradient(self.width()/2, self.height()/2,
                            max(self.width(), self.height()))
        bg.setColorAt(0, QColor(10, 10, 10))
        bg.setColorAt(0.5, QColor(5, 5, 5))
        bg.setColorAt(1, QColor(0, 0, 0))
        painter.fillRect(self.rect(), bg)

        # Red nebula effect
        nebula = QRadialGradient(
            self.width()/2 + 50 * random.uniform(-1, 1),
            self.height()/2 + 50 * random.uniform(-1, 1),
            400
        )
        nebula.setColorAt(0, QColor(220, 38, 38, 35))
        nebula.setColorAt(0.5, QColor(185, 28, 28, 20))
        nebula.setColorAt(1, QColor(0, 0, 0, 0))
        painter.fillRect(self.rect(), nebula)

        # Draw stars
        painter.setPen(Qt.PenStyle.NoPen)
        for star in self.stars:
            alpha = int(255 * star['brightness'])
            painter.setBrush(QColor(255, 255, 255, alpha))
            painter.drawEllipse(QRectF(star['x'], star['y'], star['size'], star['size']))
        
        # Draw particles
        for particle in self.particles:
            alpha = int(255 * particle.life)
            color = QColor(particle.color)
            color.setAlpha(alpha)
            painter.setBrush(color)
            painter.drawEllipse(QRectF(
                particle.x - particle.size/2,
                particle.y - particle.size/2,
                particle.size, particle.size
            ))

        # Draw comets
        painter.setPen(Qt.PenStyle.NoPen)
        for comet in self.comets:
            alpha = int(180 * comet['life'])
            painter.setBrush(QColor(248, 113, 113, alpha))
            painter.drawEllipse(QRectF(comet['x'], comet['y'], 3, 3))
            tail_pen = QPen(QColor(248, 113, 113, max(40, alpha // 2)), 2)
            painter.setPen(tail_pen)
            painter.drawLine(
                int(comet['x']),
                int(comet['y']),
                int(comet['x'] - comet['vx'] * 6),
                int(comet['y'] - comet['vy'] * 6)
            )

        # Draw pulse rings
        painter.setPen(Qt.PenStyle.NoPen)
        for ring in self.pulse_rings:
            ring_color = QColor(ring.color)
            ring_color.setAlpha(max(0, ring.alpha))
            pen = QPen(ring_color, 2)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawEllipse(QPointF(ring.x, ring.y), ring.radius, ring.radius)

        # Soft glow overlay
        glow = QRadialGradient(self.width() * 0.7, self.height() * 0.25, self.width() * 0.8)
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
        self.setFixedSize(160, 80)
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
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        
        # Opacity effect
        self.opacity_effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity_effect)
        
        # Pulse animation
        self.pulse_anim = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.pulse_anim.setDuration(1500)
        self.pulse_anim.setStartValue(0.8)
        self.pulse_anim.setEndValue(1.0)
        self.pulse_anim.setEasingCurve(QEasingCurve.Type.InOutSine)
        self.pulse_anim.finished.connect(self._reverse_pulse)
        
        # Glow animation
        self.glow_anim = QPropertyAnimation(self, b"glow_intensity")
        self.glow_anim.setDuration(600)
        self.glow_anim.setStartValue(0)
        self.glow_anim.setEndValue(30)
        self.glow_anim.setEasingCurve(QEasingCurve.Type.OutCubic)
        
        self.update_style()
    
    def _reverse_pulse(self):
        if self.pulse_anim.direction() == QPropertyAnimation.Direction.Forward:
            self.pulse_anim.setDirection(QPropertyAnimation.Direction.Backward)
        else:
            self.pulse_anim.setDirection(QPropertyAnimation.Direction.Forward)
        self.pulse_anim.start()
        
    def start_pulse(self):
        self.pulse_anim.setDirection(QPropertyAnimation.Direction.Forward)
        self.pulse_anim.start()
        
    def stop_pulse(self):
        self.pulse_anim.stop()
        self.opacity_effect.setOpacity(1.0)
    
    @pyqtProperty(int)
    def glow_intensity(self):
        return self._glow_intensity
    
    @glow_intensity.setter
    def glow_intensity(self, value):
        self._glow_intensity = value
        self.update_style()
    
    def update_style(self):
        glow = self._glow_intensity
        self.setStyleSheet(
            f"""
            QPushButton {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #ef4444, stop:1 #dc2626);
                color: white;
                font-size: 18px;
                font-weight: bold;
                font-family: 'Segoe UI';
                padding: 18px 50px;
                border-radius: 16px;
                border: none;
            }}
            QPushButton:hover {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #f87171, stop:1 #ef4444);
            }}
            QPushButton:pressed {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #dc2626, stop:1 #b91c1c);
            }}
            QPushButton:disabled {{
                background: #7f1d1d;
                color: #fca5a5;
                border: 2px solid #991b1b;
            }}
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
        self.setStyleSheet("""
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
        """)

# ===============================
# MAIN WINDOW
# ===============================
class OptimizerUI(GalaxyBackground):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"{APP_NAME} – {VERSION}")
        self.setFixedSize(1000, 700)

        layout = QVBoxLayout(self)
        layout.setSpacing(0)
        layout.setContentsMargins(30, 30, 30, 30)

        content_layout = QVBoxLayout()
        content_layout.setSpacing(18)
        content_layout.setContentsMargins(10, 0, 10, 0)

        # Header
        title = QLabel(APP_NAME)
        title.setFont(QFont("Segoe UI", 44, QFont.Weight.Bold))
        title.setStyleSheet("color: white; letter-spacing: 2px;")

        subtitle = PulseLabel("Safe & Adaptive System Optimization")
        subtitle.setFont(QFont("Segoe UI", 12))
        subtitle.setStyleSheet("color: #e5e7eb;")

        header_line = QFrame()
        header_line.setFixedHeight(2)
        header_line.setStyleSheet("background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 rgba(239,68,68,0), stop:0.5 rgba(239,68,68,0.6), stop:1 rgba(239,68,68,0)); border-radius: 1px;")

        # Stats cards
        stats_layout = QHBoxLayout()
        stats_layout.setSpacing(20)
        
        self.cleaned_card = StatCard("Cleaned", "0", "MB")
        self.optimized_card = StatCard("Applied", "0", "")
        self.cleaned_card.setFixedSize(180, 80)
        self.optimized_card.setFixedSize(180, 80)
        
        stats_layout.addStretch()
        stats_layout.addWidget(self.cleaned_card)
        stats_layout.addWidget(self.optimized_card)
        stats_layout.addStretch()

        # Button
        self.button = AnimatedButton("OPTIMIZE NOW")
        self.button.setMinimumWidth(320)
        self.button.start_pulse()
        self.button.clicked.connect(self.start_optimization)

        # Progress
        self.progress = GlowProgressBar()
        self.progress.setFixedWidth(600)
        self.progress.setValue(0)

        # Status labels
        self.status = QLabel("Ready to optimize")
        self.status.setFont(QFont("Segoe UI", 14, QFont.Weight.Bold))
        self.status.setStyleSheet("color: #f87171; letter-spacing: 0.5px;")

        self.substatus = QLabel("Click the button to begin")
        self.substatus.setFont(QFont("Segoe UI", 11))
        self.substatus.setStyleSheet("color: #fca5a5;")

        self.ai_status = PulseLabel("AI ready: adaptive optimization online", min_opacity=0.5, max_opacity=0.9)
        self.ai_status.setFont(QFont("Segoe UI", 10))
        self.ai_status.setStyleSheet("color: #fecaca;")

        # Layout assembly
        content_layout.addWidget(title, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(subtitle, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(header_line)
        content_layout.addLayout(stats_layout)
        content_layout.addSpacing(10)
        content_layout.addWidget(self.button, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(self.progress, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(self.status, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(self.substatus, alignment=Qt.AlignmentFlag.AlignHCenter)
        content_layout.addWidget(self.ai_status, alignment=Qt.AlignmentFlag.AlignHCenter)

        layout.addStretch(1)
        layout.addLayout(content_layout)
        layout.addStretch(1)

    def start_optimization(self):
        # Visual feedback
        self.button.stop_pulse()
        self.button.setEnabled(False)
        self.add_particle_burst(self.width()//2, self.height()//2 + 50, 30)
        self.add_pulse_ring(self.width()//2, self.height()//2 + 50)
        
        # Start worker
        self.worker = OptimizerWorker()
        self.worker.progress.connect(self.update_progress)
        self.worker.status.connect(self.update_status)
        self.worker.substatus.connect(self.update_substatus)
        self.worker.insight.connect(self.update_insight)
        self.worker.done.connect(self.finish_optimization)
        self.worker.error.connect(self.handle_error)
        
        Thread(target=self.worker.run, daemon=True).start()

    def update_progress(self, value):
        self.progress.setValue(value)
        if value % 10 == 0:  # Particle burst every 10%
            self.add_particle_burst(
                random.randint(100, self.width()-100),
                random.randint(100, self.height()-100),
                10
            )
            self.add_pulse_ring(self.width()//2, self.height()//2 + 50)

    def update_status(self, text):
        self.status.setText(text)

    def update_substatus(self, text):
        self.substatus.setText(text)

    def update_insight(self, text):
        self.ai_status.setText(text)

    def finish_optimization(self, stats):
        self.status.setText("✨ Optimization Complete!")
        self.substatus.setText("Your system has been optimized successfully")
        
        # Update stat cards
        self.cleaned_card.set_value(f"{stats['cleaned_mb']:.0f}")
        self.optimized_card.set_value(stats['optimizations_applied'])
        
        # Big particle burst
        self.add_particle_burst(self.width()//2, self.height()//2, 50)
        
        # Show summary
        msg = QMessageBox(self)
        msg.setWindowTitle("Optimization Complete")
        msg.setText(
            f"✅ System optimization completed!\n\n"
            f"📊 Statistics:\n"
            f"• Cleaned: {stats['cleaned_mb']:.0f} MB\n"
            f"• Optimizations: {stats['optimizations_applied']}\n"
            f"• Duration: {stats['duration']:.1f}s\n"
            f"• AI Focus: {stats['focus']} ({stats['tier']})\n"
            f"• Errors: {stats['errors']}\n"
            f"• Skipped: {stats['skipped']} (advanced features)"
        )
        msg.setIcon(QMessageBox.Icon.Information)
        msg.setStyleSheet("""
            QMessageBox {
                background: #1a1a1a;
            }
            QMessageBox QLabel {
                color: white;
                font-family: 'Segoe UI';
            }
            QPushButton {
                background: #ef4444;
                color: white;
                padding: 8px 20px;
                border-radius: 6px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: #f87171;
            }
        """)
        msg.exec()
        
        # Re-enable button
        self.button.setEnabled(True)
        self.button.start_pulse()
        self.progress.setValue(0)

    def handle_error(self, error_msg):
        self.status.setText("❌ Error occurred")
        self.substatus.setText(error_msg)
        
        QMessageBox.critical(self, "Error", f"An error occurred:\n{error_msg}")
        
        self.button.setEnabled(True)
        self.button.start_pulse()

# ===============================
# ENTRY POINT
# ===============================
if __name__ == "__main__":
    if not is_admin():
        # Request admin privileges
        try:
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{__file__}"', None, 1
            )
        except:
            QApplication(sys.argv)
            QMessageBox.critical(
                None, "Admin Required",
                "This application requires administrator privileges to run."
            )
        sys.exit()

    app = QApplication(sys.argv)
    win = OptimizerUI()
    win.show()

    sys.exit(app.exec())
