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

    print("Launching com.cricup...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(10)

    print("Tapping 'Continue with Google' at (540, 2125)...")
    run_adb(["shell", "input", "tap", "540", "2125"])
    time.sleep(4)

    print("Dumping hierarchy during Google Picker...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/picker.xml"])
    run_adb(["pull", "/sdcard/picker.xml", "scratch/picker.xml"])
    
    print("Capturing screenshot during Google Picker...")
    run_adb(["shell", "screencap", "-p", "/sdcard/picker.png"])
    run_adb(["pull", "/sdcard/picker.png", "scratch/picker.png"])
    print("Done. Saved scratch/picker.xml and scratch/picker.png")

if __name__ == "__main__":
    main()
