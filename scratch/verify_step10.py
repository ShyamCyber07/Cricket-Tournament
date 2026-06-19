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

def get_node_center_by_class(class_name, index=0):
    xml_content = get_fresh_xml()
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        nodes = [node for node in root.iter('node') if node.get('class') == class_name]
        if len(nodes) > 0 and index < len(nodes):
            bounds = nodes[index].get('bounds')
            m = re.findall(r'\d+', bounds)
            if len(m) == 4:
                x1, y1, x2, y2 = map(int, m)
                return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error parsing XML:", e)
    return None

def enter_text_in_field(field_index, text_val):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        # Clear field
        clear_keys = ["123"] + ["67"] * 30
        run_adb(["shell", "input", "keyevent"] + clear_keys)
        # Type text
        escaped_val = text_val.replace(" ", "%s")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(0.5)
        # Hide keyboard
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.0)
        return True
    return False

def main():
    # We should be on Tournament list screen. Let's tap Add Tournament FAB.
    print("Tapping Add Tournament FAB...")
    run_adb(["shell", "input", "tap", "959", "2260"])
    time.sleep(3.0)
    
    # Tap Logo Selector. Let's find "Upload Tournament Logo" text center.
    logo_text_coords = get_node_center_by_text("Upload Tournament Logo")
    if logo_text_coords:
        print(f"Tapping logo selector at ({logo_text_coords[0]}, {logo_text_coords[1] - 80})...")
        run_adb(["shell", "input", "tap", str(logo_text_coords[0]), str(logo_text_coords[1] - 80)])
        time.sleep(3.0)
        
        print("Selecting photo from gallery picker...")
        run_adb(["shell", "input", "tap", "179", "1786"])
        time.sleep(2.0)
    else:
        print("Logo text not found, trying fallback tap at (540, 480)...")
        run_adb(["shell", "input", "tap", "540", "480"])
        time.sleep(3.0)
        
    print("Entering tournament name...")
    enter_text_in_field(0, "Verify Tournament")
    
    capture_screen("6_tournament_creation_filled.png")
    
    # Scroll down to reveal submit button
    print("Scrolling down to reveal submit button...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(1.5)
    
    submit_coords = get_node_center_by_text("Create Tournament")
    if submit_coords:
        print(f"Tapping submit button at {submit_coords}...")
        run_adb(["shell", "input", "tap", str(submit_coords[0]), str(submit_coords[1])])
        time.sleep(5.0)
    else:
        print("Submit button not found by text, trying fallback tap at (540, 2060)...")
        run_adb(["shell", "input", "tap", "540", "2060"])
        time.sleep(5.0)
        
    # Capture Tournament List screen
    capture_screen("7_tournament_created_list.png")
    
    # Restart app to confirm persistence
    print("Force closing app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    
    print("Restarting app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(5.0)
    
    # Dismiss any completed match screens if they reappear
    for attempt in range(3):
        coords = get_node_center_by_text("Return to Dashboard")
        if coords:
            print(f"Dismissing completed match (Attempt {attempt+1}): tapping at {coords}")
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
            time.sleep(3.0)
            
    print("Scrolling down dashboard...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2.0)
    
    print("Tapping Tournaments card at (540, 1640)...")
    run_adb(["shell", "input", "tap", "540", "1640"])
    time.sleep(4.0)
    
    capture_screen("8_tournament_logo_persistence.png")
    print("Tournament logo verification script completed!")

if __name__ == "__main__":
    main()
