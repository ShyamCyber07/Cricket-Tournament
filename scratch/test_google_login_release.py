import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    return subprocess.check_output(cmd).decode(errors="ignore")

print("Clearing logcat...")
run_adb(["logcat", "-c"])

print("Tapping 'Continue with Google' at (540, 2125)...")
run_adb(["shell", "input", "tap", "540", "2125"])
time.sleep(4)

print("Capturing logcat logs...")
logs = run_adb(["logcat", "-d"])
for line in logs.splitlines():
    if "cricup" in line.lower() or "flutter" in line.lower() or "dio" in line.lower():
        print(line)
