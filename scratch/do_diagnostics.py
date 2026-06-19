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

def get_screen_nodes():
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/curr.xml"])
    if not xml_content.strip() or "hierarchy" not in xml_content:
        return []
    try:
        root = ET.fromstring(xml_content)
        return list(root.iter('node'))
    except Exception as e:
        print("Error parsing XML:", e)
        return []

def get_node_by_text(text_query):
    nodes = get_screen_nodes()
    for node in nodes:
        t = node.get('text', '').lower()
        d = node.get('content-desc', '').lower()
        if text_query.lower() == t or text_query.lower() == d:
            return node
    for node in nodes:
        t = node.get('text', '').lower()
        d = node.get('content-desc', '').lower()
        if text_query.lower() in t or text_query.lower() in d:
            return node
    return None

def get_node_center(node):
    bounds = node.get('bounds')
    m = re.findall(r'\d+', bounds)
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def enter_text_in_field(field_index, text_val):
    nodes = get_screen_nodes()
    edit_texts = [n for n in nodes if n.get('class') == 'android.widget.EditText']
    if field_index < len(edit_texts):
        node = edit_texts[field_index]
        coords = get_node_center(node)
        if coords:
            print(f"Entering '{text_val}' into field {field_index} at {coords}...")
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
            time.sleep(1.0)
            # Clear field (tap and backspace multiple times)
            clear_keys = ["123"] + ["67"] * 30
            run_adb(["shell", "input", "keyevent"] + clear_keys)
            # Type
            escaped_val = text_val.replace(" ", "%s")
            run_adb(["shell", "input", "text", f"'{escaped_val}'"])
            time.sleep(1.0)
            # Close keyboard
            run_adb(["shell", "input", "keyevent", "4"])
            time.sleep(1.0)
            return True
    print(f"Failed to find EditText field at index {field_index}")
    return False

def main():
    print("=== STARTING DIAGNOSTICS CONTROL ===")
    
    # 1. Clear app data
    print("Clearing app data...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2)
    
    # 2. Start app
    print("Launching app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    
    # Wait for login screen with retries
    node = None
    for attempt in range(6):
        print(f"Waiting for login screen... (Attempt {attempt+1}/6)")
        time.sleep(3)
        node = get_node_by_text("Sign Up")
        if node:
            break
            
    if not node:
        print("ERROR: Sign Up link not found on screen after 18 seconds!")
        return
        
    coords = get_node_center(node)
    print(f"Tapping Sign Up link at {coords}...")
    run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    
    # Wait for signup screen with retries
    node_signup = None
    for attempt in range(5):
        print(f"Waiting for signup screen... (Attempt {attempt+1}/5)")
        time.sleep(2)
        node_signup = get_node_by_text("Create Account")
        if node_signup:
            break
            
    if not node_signup:
        print("ERROR: Create Account screen not loaded!")
        return
    print("Signup screen loaded successfully!")
    
    # 5. Fill signup fields
    enter_text_in_field(0, "differentuser")
    enter_text_in_field(1, "cricupservice@gmail.com")
    enter_text_in_field(2, "Password123!")
    enter_text_in_field(3, "Password123!")
    
    # 6. Verify fields and click Sign Up
    nodes = get_screen_nodes()
    # Find button with text or content-desc 'Sign Up'
    btn = None
    for n in nodes:
        if n.get('class') == 'android.widget.Button' and 'sign up' in n.get('text', '').lower():
            btn = n
            break
        if n.get('class') == 'android.widget.Button' and 'sign up' in n.get('content-desc', '').lower():
            btn = n
            break
            
    if btn:
        btn_coords = get_node_center(btn)
        print(f"Tapping Sign Up button at {btn_coords}...")
        run_adb(["shell", "input", "tap", str(btn_coords[0]), str(btn_coords[1])])
    else:
        print("Sign Up button not found by text/desc, trying fallback tap at 540, 2118...")
        run_adb(["shell", "input", "tap", "540", "2118"])
        
    time.sleep(5)
    print("=== DIAGNOSTICS CONTROL COMPLETED ===")

if __name__ == "__main__":
    main()
