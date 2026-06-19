import subprocess
import os
import time
import uuid

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\570c5832-ec96-4900-a8dd-d495effc011c"

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    # Tap the EditText field to focus it
    print("Tapping EditText field...")
    run_adb(["shell", "input", "tap", "540", "1381"])
    time.sleep(1)
    
    # Generate unique name
    unique_name = f"Unique_Team_{uuid.uuid4().hex[:6]}"
    print(f"Typing team name: {unique_name}")
    
    # Type the text using adb shell input text
    run_adb(["shell", "input", "text", unique_name])
    time.sleep(1)
    
    # Hide keyboard (by pressing BACK key)
    print("Hiding keyboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1)
    
    # Tap Create button
    print("Tapping Create button...")
    run_adb(["shell", "input", "tap", "712", "1600"])
    time.sleep(3)
    
    # Dump XML and capture screenshot
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    run_adb(["pull", "/sdcard/curr.xml", "curr.xml"])
    
    dest = os.path.join(ARTIFACTS_DIR, "curr_screen.png")
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot to: {dest}")
    
    # Log the last 100 lines of logcat
    print("\n=== Logcat Output ===")
    logcat = run_adb(["logcat", "-d"])
    for line in logcat.splitlines()[-100:]:
        if "cricup" in line.lower() or "dio" in line.lower() or "teams" in line.lower():
            print(line)

if __name__ == "__main__":
    main()
