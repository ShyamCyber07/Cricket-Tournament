import subprocess
import time
import os
import re
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def get_fresh_xml():
    run_adb(["shell", "rm", "-f", "/sdcard/window_dump.xml"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    return run_adb(["shell", "cat", "/sdcard/window_dump.xml"])

def get_node_center_by_class(class_name, index=0):
    xml_content = get_fresh_xml()
    root = ET.fromstring(xml_content)
    nodes = []
    for node in root.iter('node'):
        if node.get('class') == class_name:
            nodes.append(node)
    if len(nodes) > index:
        bounds = nodes[index].get('bounds')
        m = re.findall(r'\d+', bounds)
        if len(m) == 4:
            x1, y1, x2, y2 = map(int, m)
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def enter_text_in_field(field_index, text_val):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        # Clear field (tap and backspace)
        for _ in range(30):
            run_adb(["shell", "input", "keyevent", "67"])
        run_adb(["shell", "input", "text", text_val])
        time.sleep(1)
        return True
    return False

def login():
    print("Entering email...")
    enter_text_in_field(0, "cricketer@example.com")
    print("Entering password...")
    enter_text_in_field(1, "StrongPassword123!")
    
    # Hide keyboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1)
    
    # Tap Sign In button
    print("Tapping Sign In...")
    # Sign In is at (540, 1727)
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(5)
    print("Done")

if __name__ == "__main__":
    login()
