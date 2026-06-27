import xml.etree.ElementTree as ET
import os
import subprocess

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    run_adb(["shell", "rm", "-f", "/sdcard/window_dump.xml"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    if not xml_content.strip() or "hierarchy" not in xml_content:
        print("Failed to get XML content.")
        return
        
    root = ET.fromstring(xml_content)
    print("ALL NODES IN XML DUMP:")
    for node in root.iter('node'):
        text = node.get('text', '')
        desc = node.get('content-desc', '')
        cls = node.get('class', '')
        bounds = node.get('bounds', '')
        if text or desc:
            print(f"Class: {cls} | Text: {text!r} | Desc: {desc!r} | Bounds: {bounds}")

if __name__ == "__main__":
    main()
