import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

FLUTTER_LOG_PATH = r"C:\Users\praja\.gemini\antigravity-ide\brain\3251b567-d4c2-4a27-8bf8-5ba1908b9741\.system_generated\tasks\task-623.log"
BACKEND_LOG_PATH = r"C:\Users\praja\.gemini\antigravity-ide\brain\3251b567-d4c2-4a27-8bf8-5ba1908b9741\.system_generated\tasks\task-309.log"

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
            # Tap field
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
            time.sleep(0.5)
            # Clear field using backspaces
            clear_keys = ["123"] + ["67"] * 25
            run_adb(["shell", "input", "keyevent"] + clear_keys)
            # Type text
            # Replace spaces with %s
            escaped_val = text_val.replace(" ", "%s")
            run_adb(["shell", "input", "text", f"'{escaped_val}'"])
            time.sleep(0.5)
            # Dismiss keyboard
            run_adb(["shell", "input", "keyevent", "4"])
            time.sleep(0.5)
            return True
    return False

def click_signup_button():
    nodes = get_screen_nodes()
    btn = None
    for n in nodes:
        if n.get('class') == 'android.widget.Button' and 'sign up' in n.get('text', '').lower():
            btn = n
            break
        if n.get('class') == 'android.widget.Button' and 'sign up' in n.get('content-desc', '').lower():
            btn = n
            break
    if btn:
        coords = get_node_center(btn)
        print(f"Tapping Sign Up button at {coords}...")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    else:
        print("Sign Up button not found, tapping fallback 540, 2022...")
        run_adb(["shell", "input", "tap", "540", "2022"])

def click_cancel_dialog():
    nodes = get_screen_nodes()
    cancel_btn = None
    for n in nodes:
        txt = n.get('text', '').lower()
        desc = n.get('content-desc', '').lower()
        if 'cancel' in txt or 'cancel' in desc:
            cancel_btn = n
            break
    if cancel_btn:
        coords = get_node_center(cancel_btn)
        print(f"Tapping Cancel button in dialog at {coords}...")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    else:
        print("Cancel button not found by text/desc, trying fallback tap at 310, 1420...")
        run_adb(["shell", "input", "tap", "310", "1420"])

def print_recent_logs(last_flutter_line, last_backend_line):
    # Read flutter logs
    f_lines = []
    if os.path.exists(FLUTTER_LOG_PATH):
        with open(FLUTTER_LOG_PATH, 'r', encoding='utf-8', errors='ignore') as f:
            f_lines = f.readlines()
    
    # Read backend logs
    b_lines = []
    if os.path.exists(BACKEND_LOG_PATH):
        with open(BACKEND_LOG_PATH, 'r', encoding='utf-8', errors='ignore') as f:
            b_lines = f.readlines()

    print("\n--- NEW FLUTTER LOGS ---")
    new_f = f_lines[last_flutter_line:]
    for line in new_f:
        if "[DIAGNOSTICS]" in line or "[Dio" in line:
            print(line.strip())

    print("\n--- NEW BACKEND LOGS ---")
    new_b = b_lines[last_backend_line:]
    for line in new_b:
        if "SIGNUP" in line or "auth/signup" in line or "Exception" in line or "Traceback" in line:
            print(line.strip())
            
    return len(f_lines), len(b_lines)

def main():
    print("Initializing logs line count...")
    f_len = 0
    if os.path.exists(FLUTTER_LOG_PATH):
        with open(FLUTTER_LOG_PATH, 'r', encoding='utf-8', errors='ignore') as f:
            f_len = len(f.readlines())
            
    b_len = 0
    if os.path.exists(BACKEND_LOG_PATH):
        with open(BACKEND_LOG_PATH, 'r', encoding='utf-8', errors='ignore') as f:
            b_len = len(f.readlines())

    print(f"Initial lines: Flutter={f_len}, Backend={b_len}")

    # Case 1: Duplicate Email
    print("\n==========================================")
    print("TEST CASE 1: Duplicate Email")
    print("==========================================")
    print("Entering fields...")
    enter_text_in_field(0, "uniqueusername1")
    enter_text_in_field(1, "cricupservice@gmail.com")
    enter_text_in_field(2, "Password123@")
    enter_text_in_field(3, "Password123@")
    
    click_signup_button()
    time.sleep(5)
    f_len, b_len = print_recent_logs(f_len, b_len)

    # Case 2: Duplicate Username
    print("\n==========================================")
    print("TEST CASE 2: Duplicate Username")
    print("==========================================")
    print("Entering fields...")
    enter_text_in_field(0, "cricupservice")
    enter_text_in_field(1, "uniqueemail1@gmail.com")
    enter_text_in_field(2, "Password123@")
    enter_text_in_field(3, "Password123@")
    
    click_signup_button()
    time.sleep(5)
    f_len, b_len = print_recent_logs(f_len, b_len)

    # Case 3: Existing Unverified User
    print("\n==========================================")
    print("TEST CASE 3: Existing Unverified User")
    print("==========================================")
    print("Entering fields...")
    enter_text_in_field(0, "unverifieduser")
    enter_text_in_field(1, "unverified123@gmail.com")
    enter_text_in_field(2, "Password123@")
    enter_text_in_field(3, "Password123@")
    
    click_signup_button()
    time.sleep(5)
    f_len, b_len = print_recent_logs(f_len, b_len)

    # Dismiss dialog for Case 3
    print("\nDismissing unverified user dialog...")
    click_cancel_dialog()
    time.sleep(2)
    print("Diagnostics complete!")

if __name__ == "__main__":
    main()
