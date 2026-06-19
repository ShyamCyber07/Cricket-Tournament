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

def get_node_center_by_text(text_query, index=0):
    xml_content = get_fresh_xml()
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        nodes = []
        for node in root.iter('node'):
            content_desc = node.get('content-desc', '').lower()
            text_val = node.get('text', '').lower()
            if text_query.lower() == content_desc or text_query.lower() == text_val:
                nodes.append(node)
        if not nodes:
            for node in root.iter('node'):
                content_desc = node.get('content-desc', '').lower()
                text_val = node.get('text', '').lower()
                if text_query.lower() in content_desc or text_query.lower() in text_val:
                    nodes.append(node)
        if len(nodes) > 0 and index < len(nodes):
            bounds = nodes[index].get('bounds')
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

def tap_node_by_text(text, index=0):
    coords = get_node_center_by_text(text, index)
    if coords:
        print(f"Tapping '{text}' at {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(2.0)
        return True
    return False

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
    print("Clearing app data...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2)
    
    print("Launching app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(3)
    
    # Check Onboarding Skip
    for _ in range(5):
        if check_screen_text("Skip"):
            print("Tapping Onboarding Skip...")
            tap_node_by_text("Skip")
            break
        time.sleep(1.5)
        
    print("Waiting for Login screen...")
    for _ in range(5):
        if check_screen_text("Sign In"):
            break
        time.sleep(1.5)
        
    # Enter credentials
    print("Logging in...")
    enter_text_in_field(0, "smoke_996369@gmail.com")
    enter_text_in_field(1, "Password123!")
    
    # Tap Sign In
    tap_node_by_text("Sign In")
    time.sleep(6)
    
    # Take screenshot of Dashboard
    capture_screen("0_dashboard.png")
    
if __name__ == "__main__":
    main()
