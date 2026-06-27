import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.0)
    
    print("Launching com.cricup...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(6.0)

    print("Tapping Email field...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(2.0)

    print("Typing 'hello'...")
    run_adb(["shell", "input", "text", "hello"])
    time.sleep(2.0)

    print("Capturing screenshot...")
    run_adb(["shell", "screencap", "-p", "/sdcard/test_input.png"])
    run_adb(["pull", "/sdcard/test_input.png", "scratch/test_input.png"])
    print("Screenshot pulled to scratch/test_input.png")

if __name__ == "__main__":
    main()
