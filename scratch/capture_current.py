import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\fa542cae-bc56-4ca4-934a-ad5207d414e4"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def capture_screen(filename):
    dest = os.path.join(ARTIFACTS_DIR, filename)
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured: {filename} -> {dest}")

capture_screen("current_screen.png")
