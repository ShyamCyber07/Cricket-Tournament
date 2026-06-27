import os
import time
import xml.etree.ElementTree as ET
import sys

sys.stdout.reconfigure(encoding='utf-8')

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    return os.popen(" ".join(cmd)).read()

print("Force stopping and launching...")
run_adb(["shell", "am", "force-stop", "com.cricup"])
time.sleep(1.0)
run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
time.sleep(5.0)

# Sign in as player
print("Logging in...")
run_adb(["shell", "input", "tap", "540", "1214"])
time.sleep(0.5)
for _ in range(25): run_adb(["shell", "input", "keyevent", "67"])
run_adb(["shell", "input", "text", "player@cricup.com"])
run_adb(["shell", "input", "keyevent", "4"])
time.sleep(0.5)
run_adb(["shell", "input", "tap", "540", "1423"])
time.sleep(0.5)
for _ in range(25): run_adb(["shell", "input", "keyevent", "67"])
run_adb(["shell", "input", "text", "Password123"])
run_adb(["shell", "input", "keyevent", "4"])
time.sleep(0.5)
run_adb(["shell", "input", "tap", "540", "1727"])
time.sleep(6.0)

# Open notifications screen
print("Tapping notifications button (750, 160)...")
run_adb(["shell", "input", "tap", "750", "160"])
time.sleep(4.0)

print("Dumping Notifications screen...")
run_adb(["shell", "uiautomator", "dump", "/data/local/tmp/notifs_screen.xml"])
run_adb(["pull", "/data/local/tmp/notifs_screen.xml", "notifs_screen.xml"])

tree = ET.parse("notifs_screen.xml")
root = tree.getroot()

for node in root.iter("node"):
    text = node.get("text", "")
    desc = node.get("content-desc", "")
    bounds = node.get("bounds", "")
    if text or desc:
        print(f"Node: class={node.get('class')} | desc='{desc}' | text='{text}' | bounds={bounds}")
