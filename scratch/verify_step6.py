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
    # We are currently in Team Management. Let's go back to dashboard.
    print("Pressing back to return to dashboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(2.0)
    
    # Scroll down to reveal Quick Management if it's not visible
    print("Scrolling down dashboard...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(1.5)
    
    # Tap Tournaments
    print("Tapping Tournaments card at (540, 1815)...")
    run_adb(["shell", "input", "tap", "540", "1815"])
    time.sleep(3.0)
    
    print("Tournament list screen nodes:")
    dump_screen_nodes()
    
    # Let's find the Add Tournament FAB/button.
    # Usually it's at the bottom right. Let's check the XML nodes dump.
    
if __name__ == "__main__":
    main()
