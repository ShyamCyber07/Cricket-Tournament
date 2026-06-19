import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def get_fresh_xml(retries=5):
    for attempt in range(retries):
        time.sleep(1.0)
        run_adb(["shell", "rm", "-f", "/sdcard/window_dump.xml"])
        dump_res = run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
        if "dumped to" in dump_res or "UI hierchary" in dump_res:
            xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
            if xml_content.strip() and "hierarchy" in xml_content:
                try:
                    ET.fromstring(xml_content)
                    return xml_content
                except Exception:
                    pass
        time.sleep(1.0)
    return ""

def get_node_center_by_text(text_query):
    xml_content = get_fresh_xml()
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            content_desc = node.get('content-desc', '').lower()
            text_val = node.get('text', '').lower()
            if text_query.lower() == content_desc or text_query.lower() == text_val or text_query.lower() in content_desc or text_query.lower() in text_val:
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error parsing XML:", e)
    return None

def check_screen_text(text_query):
    xml_content = get_fresh_xml()
    return text_query.lower() in xml_content.lower()

def dump_screen_nodes():
    xml_content = get_fresh_xml()
    if not xml_content:
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

def main():
    # Loop to clear any "Return to Dashboard" screens
    for attempt in range(5):
        if check_screen_text("Return to Dashboard"):
            coords = get_node_center_by_text("Return to Dashboard")
            if coords:
                print(f"Dismissing completed match (Attempt {attempt+1}): tapping at {coords}")
                run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
                time.sleep(3.0)
        else:
            break
            
    print("Scrolling down dashboard...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(1.5)
    
    print("Tapping Tournaments card at (540, 1815)...")
    run_adb(["shell", "input", "tap", "540", "1815"])
    time.sleep(3.0)
    
    print("Tournament list screen nodes:")
    dump_screen_nodes()

if __name__ == "__main__":
    main()
