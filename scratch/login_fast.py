import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def dismiss_keyboard_if_shown():
    dumpsys = run_adb(["shell", "dumpsys", "input_method"])
    if "mInputShown=true" in dumpsys:
        print("Keyboard is shown, dismissing...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.5)
    else:
        print("Keyboard is not shown, skipping dismissal.")

def wait_for_login_screen():
    print("Waiting for login screen to load...")
    for attempt in range(20):
        run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
        xml = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
        if "EditText" in xml or "Sign In" in xml or "Cric" in xml:
            print("Login screen loaded!")
            time.sleep(4.0) # Let it settle completely
            return True
        print(f"Not loaded yet, waiting 2s... (attempt {attempt+1}/20)")
        time.sleep(2.0)
    return False

def main():
    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(2)

    print("Launching com.cricup...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    
    if not wait_for_login_screen():
        print("ERROR: Login screen did not load in time!")
        return

    print("Tapping email field...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(1.0)
    
    print("Typing email...")
    run_adb(["shell", "input", "text", "cricupservice@gmail.com"])
    time.sleep(1.0)
    
    dismiss_keyboard_if_shown()
    
    print("Tapping password field...")
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(1.0)
    
    print("Typing password...")
    run_adb(["shell", "input", "text", "Password123\\!"])
    time.sleep(1.0)
    
    dismiss_keyboard_if_shown()
    
    print("Tapping Sign In...")
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(8.0)
    print("Fast login sequence completed.")

if __name__ == "__main__":
    main()
