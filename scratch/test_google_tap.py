import subprocess
import os
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Setting up ADB reverse forwarding...")
    print(run_adb(["reverse", "tcp:8000", "tcp:8000"]))
    time.sleep(1)

    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1)

    print("Clearing logcat...")
    run_adb(["logcat", "-c"])

    print("Launching com.cricup...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    
    print("Waiting 10 seconds for app to fully load and settle...")
    time.sleep(10)

    print("Tapping 'Continue with Google' at (540, 2125)...")
    run_adb(["shell", "input", "tap", "540", "2125"])
    
    print("Waiting 10 seconds for Google Sign-In response...")
    time.sleep(10)

    print("Capturing screenshot...")
    run_adb(["shell", "screencap", "-p", "/sdcard/google_tap_screen.png"])
    run_adb(["pull", "/sdcard/google_tap_screen.png", "scratch/google_tap_screen.png"])
    
    print("Dumping hierarchy...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/google_tap_window.xml"])
    run_adb(["pull", "/sdcard/google_tap_window.xml", "scratch/google_tap_window.xml"])
    
    print("Capturing logcat logs...")
    logs = run_adb(["logcat", "-d"])
    with open("scratch/google_tap_logcat.txt", "w", encoding="utf-8") as f:
        f.write(logs)
    
    print("\n--- Relevant Logcat Logs ---")
    for line in logs.splitlines():
        if any(k in line.lower() for k in ["cricup", "google", "auth", "sign-in", "login", "dio", "platformexception", "firebase"]):
            if not any(n in line.lower() for n in ["notification", "keyguard", "power", "battery"]):
                print(line)

if __name__ == "__main__":
    main()
