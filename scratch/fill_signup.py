import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB, "-s", "f35c3099"] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def get_node_center_by_class(class_name, index=0):
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    try:
        root = ET.fromstring(xml_content)
        nodes = []
        for node in root.iter('node'):
            if node.get('class') == class_name:
                nodes.append(node)
        if index < len(nodes):
            bounds = nodes[index].get('bounds')
            m = re.findall(r'\d+', bounds)
            if len(m) == 4:
                x1, y1, x2, y2 = map(int, m)
                return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error:", e)
    return None

def enter_text_in_field(field_index, text_val):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        # Clear field (tap and backspace multiple times)
        clear_keys = ["123"] + ["67"] * 25
        run_adb(["shell", "input", "keyevent"] + clear_keys)
        # Type
        escaped_val = text_val.replace(" ", "%s")
        run_adb(["shell", "input", "text", f"'{escaped_val}'"])
        time.sleep(0.5)

def main():
    print("Entering fields...")
    enter_text_in_field(0, "differentuser")
    enter_text_in_field(1, "cricupservice@gmail.com")
    
    # Let's hide keyboard or dismiss it if shown
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.5)
    
    enter_text_in_field(2, "Password123!")
    
    # Hide keyboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.5)
    
    enter_text_in_field(3, "Password123!")
    
    # Hide keyboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(0.5)
    
    print("Tapping Sign Up...")
    run_adb(["shell", "input", "tap", "540", "2118"])
    time.sleep(3)
    print("Done")

if __name__ == "__main__":
    main()
