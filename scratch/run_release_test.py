import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    return subprocess.check_output(cmd).decode(errors="ignore")

def get_pid():
    try:
        return run_adb(["shell", "pidof", "com.cricup"]).strip()
    except Exception:
        return None

# Clears the logcat buffer
print("Clearing logcat...")
run_adb(["logcat", "-c"])

# Click email field
print("Tapping email field...")
run_adb(["shell", "input", "tap", "540", "1214"])
time.sleep(1)

# Type email
print("Entering email...")
run_adb(["shell", "input", "text", "cricupservice@gmail.com"])
time.sleep(1)

# Click password field
print("Tapping password field...")
run_adb(["shell", "input", "tap", "540", "1423"])
time.sleep(1)

# Type password
print("Entering password...")
run_adb(["shell", "input", "text", "Password123@"])
time.sleep(1)

# Hide keyboard
print("Hiding keyboard...")
run_adb(["shell", "input", "keyevent", "4"])
time.sleep(1.5)

# Click Sign In button
print("Tapping Sign In...")
run_adb(["shell", "input", "tap", "540", "1727"])
time.sleep(4)

# Dump logcat logs
pid = get_pid()
print(f"App PID: {pid}")
if pid:
    print("Capturing logcat logs...")
    logs = run_adb(["logcat", "-d"])
    for line in logs.splitlines():
        if "cricup" in line.lower() or "flutter" in line.lower() or "dio" in line.lower():
            print(line)
else:
    print("App is not running!")
