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

def is_keyboard_shown():
    dumpsys = run_adb(["shell", "dumpsys", "input_method"])
    return "mInputShown=true" in dumpsys

def check_keyboard_and_dismiss():
    if is_keyboard_shown():
        print("Keyboard is shown, dismissing...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.5)

def get_xml_hierarchy():
    run_adb(["shell", "rm", "-f", "/sdcard/diag_dump.xml"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/diag_dump.xml"])
    return run_adb(["shell", "cat", "/sdcard/diag_dump.xml"])

def print_field_states(step_name):
    print(f"\n--- Field states at step: {step_name} ---")
    xml_content = get_xml_hierarchy()
    if not xml_content:
        print("Failed to get XML")
        return
    try:
        root = ET.fromstring(xml_content)
        edits = [node for node in root.iter('node') if node.get('class') == "android.widget.EditText"]
        for idx, node in enumerate(edits):
            text = node.get('text', '')
            focused = node.get('focused', '')
            bounds = node.get('bounds', '')
            print(f"EditText {idx}: text='{text}', focused={focused}, bounds={bounds}")
    except Exception as e:
        print("Error parsing XML:", e)

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
                    print(f"Tapping Skip at {cx}, {cy}")
                    run_adb(["shell", "input", "tap", str(cx), str(cy)])
                    time.sleep(2.0)
                    break

    print_field_states("After Launch & Skip")

    # Enter Email
    print("\nEntering Email...")
    field0 = get_node_center_by_class("android.widget.EditText", 0)
    if field0:
        print(f"Tapping Email field at {field0}...")
        run_adb(["shell", "input", "tap", str(field0[0]), str(field0[1])])
        time.sleep(0.5)
        run_adb(["shell", "input", "tap", str(field0[0]), str(field0[1])])
        time.sleep(1.5)
        
        print("Typing Email text...")
        run_adb(["shell", "input", "text", "testuser@cricup.com"])
        time.sleep(1.5)
        print_field_states("After typing Email (keyboard open)")
        
        print("Dismissing keyboard...")
        check_keyboard_and_dismiss()
        print_field_states("After dismissing Email keyboard")

    # Enter Password
    print("\nEntering Password...")
    field1 = get_node_center_by_class("android.widget.EditText", 1)
    if field1:
        print(f"Tapping Password field at {field1}...")
        run_adb(["shell", "input", "tap", str(field1[0]), str(field1[1])])
        time.sleep(0.5)
        run_adb(["shell", "input", "tap", str(field1[0]), str(field1[1])])
        time.sleep(1.5)
        
        print("Typing Password text...")
        run_adb(["shell", "input", "text", "Password123!"])
        time.sleep(1.5)
        print_field_states("After typing Password (keyboard open)")
        
        print("Dismissing keyboard...")
        check_keyboard_and_dismiss()
        print_field_states("After dismissing Password keyboard")

    print("\nTapping Sign In button...")
    # Find Sign In button bounds
    xml = get_xml_hierarchy()
    root = ET.fromstring(xml)
    btn_coords = (540, 1727)
    for node in root.iter('node'):
        desc = node.get('content-desc', '')
        if "sign in" in desc.lower() and node.get('class') == "android.widget.Button":
            bounds = node.get('bounds')
            m = re.findall(r'\d+', bounds)
            if len(m) == 4:
                x1, y1, x2, y2 = map(int, m)
                btn_coords = ((x1 + x2) // 2, (y1 + y2) // 2)
                break
    print(f"Tapping Sign In button at {btn_coords}...")
    run_adb(["shell", "input", "tap", str(btn_coords[0]), str(btn_coords[1])])
    time.sleep(7.0)

    print_field_states("After Sign In click")

def get_node_center_by_class(class_name, index=0):
    xml_content = get_xml_hierarchy()
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
        pass
    return None

if __name__ == "__main__":
    main()
