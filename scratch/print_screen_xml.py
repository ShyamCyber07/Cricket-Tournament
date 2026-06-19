import xml.etree.ElementTree as ET
import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/curr.xml"])
    if not xml_content.strip() or "hierarchy" not in xml_content:
        print("No UI hierarchy found.")
        return
    
    try:
        root = ET.fromstring(xml_content)
        for i, node in enumerate(root.iter('node')):
            text = node.get('text', '')
            desc = node.get('content-desc', '')
            cls = node.get('class', '')
            bounds = node.get('bounds', '')
            if text or desc:
                print(f"[{i}] Class: {cls} | Text: '{text}' | Desc: '{desc}' | Bounds: {bounds}")
    except Exception as e:
        print("Error parsing XML:", e)

if __name__ == "__main__":
    main()
