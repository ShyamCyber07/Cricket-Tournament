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
    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1)

    print("Clearing logcat...")
    run_adb(["logcat", "-c"])

    print("Launching com.cricup...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(4)

    print("Tapping 'Continue with Google' at (540, 2125)...")
    run_adb(["shell", "input", "tap", "540", "2125"])
    
    print("Waiting 15 seconds for auth flow to complete...")
    time.sleep(15)

    print("Capturing screenshot...")
    run_adb(["shell", "screencap", "-p", "/sdcard/google_auth_screen.png"])
    run_adb(["pull", "/sdcard/google_auth_screen.png", "scratch/google_auth_screen.png"])
    
    print("Dumping hierarchy...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/google_auth_window.xml"])
    run_adb(["pull", "/sdcard/google_auth_window.xml", "scratch/google_auth_window.xml"])
    
    print("Capturing logcat logs...")
    logs = run_adb(["logcat", "-d"])
    with open("scratch/google_auth_logcat.txt", "w", encoding="utf-8") as f:
        f.write(logs)
    
    print("\n--- Relevant Logcat Logs ---")
    for line in logs.splitlines():
        if any(k in line.lower() for k in ["cricup", "google", "auth", "sign-in", "login", "dio", "platformexception", "firebase"]):
            # Filter out some very common noisy unrelated lines if any
            if not any(n in line.lower() for n in ["notification", "keyguard", "power", "battery"]):
                print(line)

if __name__ == "__main__":
    main()
