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
    print("Tapping email field...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(1.0)
    
    print("Clearing email field...")
    for _ in range(40):
        run_adb(["shell", "input", "keyevent", "67"]) # backspace
    
    print("Typing email...")
    run_adb(["shell", "input", "text", "cricketer@example.com"])
    time.sleep(1.0)
    
    print("Tapping password field...")
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(1.0)
    
    print("Clearing password field...")
    for _ in range(40):
        run_adb(["shell", "input", "keyevent", "67"]) # backspace
        
    print("Typing password...")
    run_adb(["shell", "input", "text", "StrongPassword123!"])
    time.sleep(1.0)
    
    print("Dismissing keyboard...")
    run_adb(["shell", "input", "keyevent", "4"]) # Back button to hide keyboard
    time.sleep(1.0)
    
    print("Tapping Sign In...")
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(5.0)
    print("Login sequence finished.")

if __name__ == "__main__":
    main()
