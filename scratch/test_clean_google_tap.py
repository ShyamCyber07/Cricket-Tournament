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

    print("Clearing com.cricup data to force logout...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2)

    print("Clearing logcat...")
    run_adb(["logcat", "-c"])

    print("Launching com.cricup...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    
    print("Waiting 12 seconds for app to fully load welcome screen...")
    time.sleep(12)

    print("Tapping 'Continue with Google' at (540, 2125)...")
    run_adb(["shell", "input", "tap", "540", "2125"])
    
    print("Waiting 15 seconds for Google Sign-In account picker and response...")
    time.sleep(15)

    print("Capturing screenshot...")
    run_adb(["shell", "screencap", "-p", "/sdcard/google_clean_tap.png"])
    run_adb(["pull", "/sdcard/google_clean_tap.png", "scratch/google_clean_tap.png"])
    
    print("Dumping hierarchy...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/google_clean_tap.xml"])
    run_adb(["pull", "/sdcard/google_clean_tap.xml", "scratch/google_clean_tap.xml"])
    
    print("Capturing logcat logs...")
    logs = run_adb(["logcat", "-d"])
    with open("scratch/google_clean_tap_logcat.txt", "w", encoding="utf-8") as f:
        f.write(logs)
    
    print("\n--- Relevant Logcat Logs ---")
    for line in logs.splitlines():
        if any(k in line.lower() for k in ["cricup", "google", "auth", "sign-in", "login", "dio", "platformexception", "firebase"]):
            if not any(n in line.lower() for n in ["notification", "keyguard", "power", "battery"]):
                print(line)

if __name__ == "__main__":
    main()
