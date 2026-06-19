import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\94eac4a0-b0f2-4d53-af50-94b2590d43d8"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def capture_screen(filename):
    dest = os.path.join(ARTIFACTS_DIR, filename)
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot: {filename}")

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
    print("Tapping Add Team FAB...")
    run_adb(["shell", "input", "tap", "959", "2260"])
    time.sleep(2.0)
    
    print("Dumping Create Team Dialog XML...")
    dump_screen_nodes()
    capture_screen("1_create_team_dialog.png")
    
    # Tap "Tap to upload logo". The text bounds should tell us its position,
    # but let's look at the dump first. Wait, let's just tap around (540, 1100) or
    # let's write a python script to search for the node and tap it.
    # We can do that by parsing the xml inside python.
    xml_content = run_adb(["shell", "cat", "/sdcard/curr.xml"])
    root = ET.fromstring(xml_content)
    target = None
    for node in root.iter('node'):
        text = node.get('text', '').lower()
        desc = node.get('content-desc', '').lower()
        if "tap to upload logo" in text or "tap to upload logo" in desc:
            target = node
            break
            
    if target is not None:
        bounds = target.get('bounds')
        m = re.findall(r'\d+', bounds)
        x1, y1, x2, y2 = map(int, m)
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        print(f"Tapping 'Tap to upload logo' at ({cx}, {cy})...")
        run_adb(["shell", "input", "tap", str(cx), str(cy - 80)]) # Tap slightly above the text (where the circle is)
        time.sleep(3.0)
        
        print("Captured gallery picker screen:")
        capture_screen("2_gallery_picker.png")
        dump_screen_nodes()
    else:
        print("Could not find 'Tap to upload logo' element!")

if __name__ == "__main__":
    main()
