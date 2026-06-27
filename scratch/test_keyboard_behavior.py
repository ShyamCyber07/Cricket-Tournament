import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def is_keyboard_shown():
    dumpsys = run_adb(["shell", "dumpsys", "input_method"])
    return "mInputShown=true" in dumpsys

def main():
    print("Clearing app data...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)
    
    print("Launching app...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(8.0) # wait extra long for first run initialization

    print(f"Initially, keyboard shown? {is_keyboard_shown()}")

    print("Tapping Email field once...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(1.5)
    print(f"After 1 tap, keyboard shown? {is_keyboard_shown()}")

    if not is_keyboard_shown():
        print("Tapping Email field a second time...")
        run_adb(["shell", "input", "tap", "540", "1214"])
        time.sleep(1.5)
        print(f"After 2 taps, keyboard shown? {is_keyboard_shown()}")

    if is_keyboard_shown():
        print("Typing 'hello'...")
        run_adb(["shell", "input", "text", "hello"])
        time.sleep(1.0)
        
        # Take screenshot
        run_adb(["shell", "screencap", "-p", "/sdcard/keyboard_success.png"])
        run_adb(["pull", "/sdcard/keyboard_success.png", "scratch/keyboard_success.png"])
        print("Captured keyboard_success.png")
    else:
        print("Keyboard failed to open. Capturing error state...")
        run_adb(["shell", "screencap", "-p", "/sdcard/keyboard_fail.png"])
        run_adb(["pull", "/sdcard/keyboard_fail.png", "scratch/keyboard_fail.png"])
        
        # Also dump UI XML
        run_adb(["shell", "uiautomator", "dump", "/sdcard/keyboard_fail.xml"])
        run_adb(["pull", "/sdcard/keyboard_fail.xml", "scratch/keyboard_fail.xml"])

if __name__ == "__main__":
    main()
