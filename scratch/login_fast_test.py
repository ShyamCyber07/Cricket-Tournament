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
    time.sleep(2)

    print("Launching com.cricup...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(6)

    # Tap email field
    print("Tapping email field...")
    run_adb(["shell", "input", "tap", "540", "1214"])
    time.sleep(1.5)

    # Type email
    print("Typing email...")
    run_adb(["shell", "input", "text", "cricupservice@gmail.com"])
    time.sleep(1.5)

    # Tap password field
    print("Tapping password field...")
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(1.5)

    # Type password
    print("Typing password...")
    run_adb(["shell", "input", "text", "Password123!"])
    time.sleep(1.5)

    # Dismiss keyboard
    print("Dismissing keyboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.5)

    # Tap Sign In
    print("Tapping Sign In...")
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(8)

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

    print("Finished.")

if __name__ == "__main__":
    main()
