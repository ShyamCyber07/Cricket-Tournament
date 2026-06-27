import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\f6bf628d-b51a-49d1-b74c-ef2a8844701a"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Clearing logcat...")
    run_adb(["logcat", "-c"])
    
    print("Tapping 'Continue with Google' at (540, 2102)...")
    run_adb(["shell", "input", "tap", "540", "2102"])
    
    # Wait for account picker or error popup
    time.sleep(8.0)
    
    print("Capturing screenshot...")
    screenshot_path = os.path.join(ARTIFACTS_DIR, "google_click_1.png")
    run_adb(["shell", "screencap", "-p", "/sdcard/google_click_1.png"])
    run_adb(["pull", "/sdcard/google_click_1.png", screenshot_path])
    print(f"Saved screenshot to: {screenshot_path}")
    
    print("Dumping hierarchy...")
    xml_path = os.path.join(ARTIFACTS_DIR, "google_click_1.xml")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/google_click_1.xml"])
    run_adb(["pull", "/sdcard/google_click_1.xml", xml_path])
    print(f"Saved hierarchy dump to: {xml_path}")
    
    print("Capturing logcat logs...")
    log_path = os.path.join(ARTIFACTS_DIR, "google_click_1_logcat.txt")
    logs = run_adb(["logcat", "-d"])
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(logs)
    print(f"Saved logcat to: {log_path}")
    
    # Print relevant logs to console
    print("\n--- Relevant Logs ---")
    for line in logs.splitlines():
        if any(k in line.lower() for k in ["cricup", "google", "auth", "sign-in", "login", "dio", "platformexception"]):
            print(line)

if __name__ == "__main__":
    main()
