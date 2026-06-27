import xml.etree.ElementTree as ET
import os
import subprocess
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    # Tap Explore Teams tab
    print("Tapping Explore Teams tab...")
    run_adb(["shell", "input", "tap", "810", "303"])
    time.sleep(3.0)
    
    # Dump XML
    run_adb(["shell", "rm", "-f", "/sdcard/window_dump.xml"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    
    root = ET.fromstring(xml_content)
    print("EXPLORE TEAMS NODES:")
    for node in root.iter('node'):
        text = node.get('text', '')
        desc = node.get('content-desc', '')
        cls = node.get('class', '')
        bounds = node.get('bounds', '')
        if text or desc:
            print(f"Class: {cls} | Text: {text!r} | Desc: {desc!r} | Bounds: {bounds}")

if __name__ == "__main__":
    main()
