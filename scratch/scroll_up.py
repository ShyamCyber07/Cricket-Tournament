import subprocess
import os
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
REAL_ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\570c5832-ec96-4900-a8dd-d495effc011c"

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Scrolling up dashboard...")
    run_adb(["shell", "input", "swipe", "500", "600", "500", "1800", "500"])
    time.sleep(2)

    print("Dumping UI hierarchy...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    run_adb(["pull", "/sdcard/curr.xml", "curr.xml"])

    dest = os.path.join(REAL_ARTIFACTS_DIR, "curr_screen.png")
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot to: {dest}")

if __name__ == "__main__":
    main()
