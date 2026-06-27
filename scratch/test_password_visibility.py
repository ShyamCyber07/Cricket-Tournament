import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def get_xml_hierarchy():
    run_adb(["shell", "rm", "-f", "/sdcard/pwd_vis_dump.xml"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/pwd_vis_dump.xml"])
    return run_adb(["shell", "cat", "/sdcard/pwd_vis_dump.xml"])

def main():
    print("Clearing app data...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)
    
    print("Launching app...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(6.0)

    # Check for skip onboarding
    xml = get_xml_hierarchy()
    if "skip" in xml.lower():
        print("Skip button detected, tapping Skip...")
        # Find skip coordinates
        root = ET.fromstring(xml)
        for node in root.iter('node'):
            text = node.get('text', '') or node.get('content-desc', '')
            if "skip" in text.lower():
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
                    run_adb(["shell", "input", "tap", str(cx), str(cy)])
                    time.sleep(2.0)
                    break

    # Tap Password field to focus
    print("Tapping Password field...")
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(0.5)
    run_adb(["shell", "input", "tap", "540", "1423"])
    time.sleep(1.5)
    
    print("Typing Password text 'Password123!'...")
    run_adb(["shell", "input", "text", "Password123!"])
    time.sleep(1.5)
    
    print("Tapping visibility toggle at (878, 1424)...")
    run_adb(["shell", "input", "tap", "878", "1424"])
    time.sleep(1.5)
    
    print("Dumping hierarchy to inspect text...")
    xml_content = get_xml_hierarchy()
    if xml_content:
        root = ET.fromstring(xml_content)
        edits = [node for node in root.iter('node') if node.get('class') == "android.widget.EditText"]
        for idx, node in enumerate(edits):
            text = node.get('text', '')
            pw = node.get('password', '')
            print(f"EditText {idx}: text='{text}', password={pw}")
            
    # Capture screen
    run_adb(["shell", "screencap", "-p", "/sdcard/pwd_vis.png"])
    run_adb(["pull", "/sdcard/pwd_vis.png", "scratch/pwd_vis.png"])
    print("Screenshot pulled to scratch/pwd_vis.png")

if __name__ == "__main__":
    main()
