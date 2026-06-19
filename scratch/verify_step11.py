import subprocess
import time
import os
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def dump_screen_nodes():
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
    except ET.ParseError as e:
        print("Error parsing XML:", e)

def main():
    print("Pressing back to go back to dashboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(2.0)
    
    # We are on the dashboard. Let's scroll up slightly if needed, but the live match
    # CSK vs RCB or Mumbai Indians vs CSK should be visible at the top.
    # In the previous dump, 'Mumbai Indians 1781688870 vs Chennai Super Kings 1781688870'
    # was at bounds [55,237][1025,388]. Center is (540, 312). Let's tap it!
    print("Tapping on live match at (540, 312)...")
    run_adb(["shell", "input", "tap", "540", "312"])
    time.sleep(4.0)
    
    print("Match screen nodes:")
    dump_screen_nodes()

if __name__ == "__main__":
    main()
