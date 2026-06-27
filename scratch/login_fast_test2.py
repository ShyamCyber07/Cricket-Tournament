import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def wait_for_login_screen():
    print("Waiting for login screen to load...")
    for attempt in range(20):
        run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
        xml = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
        if "EditText" in xml or "Sign In" in xml or "Cric" in xml:
            print("Login screen loaded!")
            time.sleep(3.0) # Let it settle completely
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

    # Tap Email field
    print("Tapping email field...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(1.5)

    # Type Email
    print("Typing email...")
    run_adb(["shell", "input", "text", "cricupservice@gmail.com"])
    time.sleep(1.5)

    # Tap Password field directly (without dismissing keyboard)
    print("Tapping password field...")
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(1.5)

    # Type Password (we use Password123! directly)
    print("Typing password...")
    run_adb(["shell", "input", "text", "Password123!"])
    time.sleep(1.5)

    # Now dismiss keyboard to reveal Sign In button
    print("Dismissing keyboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.5)

    # Tap Sign In
    print("Tapping Sign In...")
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(8.0)

    # Capture screen
    print("Capturing screen...")
    dest = r"C:\Users\praja\.gemini\antigravity-ide\brain\f6bf628d-b51a-49d1-b74c-ef2a8844701a\screen.png"
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])

    # Dump XML
    print("Dumping hierarchy...")
    xml_dest = r"C:\Users\praja\.gemini\antigravity-ide\brain\f6bf628d-b51a-49d1-b74c-ef2a8844701a\window_dump.xml"
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    run_adb(["pull", "/sdcard/window_dump.xml", xml_dest])

    print("Finished E2E Login test.")

if __name__ == "__main__":
    main()
