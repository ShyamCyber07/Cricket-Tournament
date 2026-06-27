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
    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.0)
    
    print("Clearing app data...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)
    
    print("Launching app...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(6.0)
    
    print("Bypassing onboarding...")
    run_adb(["shell", "input", "tap", "975", "160"]) # Tap Skip top-right
    time.sleep(3.0)
    
    print("Tapping email field...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(1.0)
    
    print("Typing email...")
    run_adb(["shell", "input", "text", "captain@cricup.com"])
    time.sleep(2.0)
    
    print("Tapping password field...")
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(1.0)
    
    print("Typing password...")
    run_adb(["shell", "input", "text", "Password123!"])
    time.sleep(2.0)
    
    print("Dismissing keyboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.5)
    
    print("Tapping Sign In...")
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(6.0)
    
    print("Capturing debug screenshot...")
    run_adb(["shell", "screencap", "-p", "/sdcard/debug_input.png"])
    run_adb(["pull", "/sdcard/debug_input.png", "scratch/debug_input.png"])
    print("Done. Screenshot saved to scratch/debug_input.png")

if __name__ == "__main__":
    main()
