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

def check_screen_text(text_query, retries=3):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if text_query.lower() in xml_content.lower():
            return True
        if retries > 1:
            time.sleep(1.5)
    return False

def get_node_center_by_text(text_query, index=0, retries=5):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            continue
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
            pass
        time.sleep(1.0)
    return None

def tap_node_by_text(text, index=0, wait_secs=3):
    coords = get_node_center_by_text(text, index)
    if coords:
        print(f"Tapping '{text}' at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    print(f"WARNING: Could not find node with text '{text}'")
    return False

def get_node_center_by_class(class_name, index=0, retries=5):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            continue
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
        time.sleep(1.0)
    return None

def is_keyboard_shown():
    dumpsys = run_adb(["shell", "dumpsys", "input_method"])
    return "mInputShown=true" in dumpsys

def check_keyboard_and_dismiss():
    if is_keyboard_shown():
        print("Keyboard is shown, dismissing...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.5)
    else:
        print("Keyboard not shown, no need to dismiss.")

def clear_field(backspaces=30):
    for _ in range(backspaces):
        run_adb(["shell", "input", "keyevent", "67"]) # Backspace
        time.sleep(0.05)
    time.sleep(0.5)

def enter_text_in_field(field_index, text_val):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        print(f"EditText index {field_index} found at center {field}. Tapping to focus...")
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(1.5)
        
        # Verify keyboard is shown, try recovery tap if not
        if not is_keyboard_shown():
            print("Keyboard did not show, attempting recovery tap...")
            run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
            time.sleep(1.5)
            
        # Clear field completely
        clear_field(30 if field_index == 0 else 20)
        
        # Input text
        escaped_val = text_val.replace(" ", "%s")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(1.0)
        
        # Dismiss keyboard
        check_keyboard_and_dismiss()
        return True
    print(f"WARNING: Could not find EditText at index {field_index}")
    return False

def main():
    print("Setting up ADB reverse port forwarding for port 8000...")
    run_adb(["reverse", "tcp:8000", "tcp:8000"])
    time.sleep(1.0)
    
    print("Force stopping Gboard settings and other packages...")
    run_adb(["shell", "am", "force-stop", "com.google.android.inputmethod.latin"])
    
    print("Pre-test setup: Resetting app data to start in logged-out state...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)
    
    success_count = 0
    total_cycles = 20

    print("Clearing logcat...")
    run_adb(["logcat", "-c"])

    for i in range(1, total_cycles + 1):
        print(f"\n=================== CYCLE {i} / {total_cycles} ===================")
        try:
            # Force stop first and then start the app
            run_adb(["shell", "am", "force-stop", "com.cricup"])
            time.sleep(1.0)
            
            print("Launching app...")
            run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
            
            # Wait for launch and check onboarding or login
            print("Waiting for app to load...")
            on_welcome_or_onboarding = False
            for attempt in range(15):
                if check_screen_text("Skip") or check_screen_text("welcome back") or check_screen_text("continue with google"):
                    on_welcome_or_onboarding = True
                    break
                time.sleep(1.0)
                
            if not on_welcome_or_onboarding:
                print(f"ERROR in Cycle {i}: App did not load correct initial screen.")
                run_adb(["shell", "screencap", "-p", f"/sdcard/cycle_{i}_launch_error.png"])
                run_adb(["pull", f"/sdcard/cycle_{i}_launch_error.png", f"scratch/cycle_{i}_launch_error.png"])
                raise Exception("App launch timeout/error.")
                
            # If onboarding Skip is visible, tap it!
            if check_screen_text("Skip"):
                print("Onboarding screen detected. Tapping Skip...")
                tap_node_by_text("Skip")
                time.sleep(2.0)
                
            # Now verify we are on the welcome screen
            if not check_screen_text("welcome back") and not check_screen_text("continue with google"):
                print(f"ERROR in Cycle {i}: Welcome screen not loaded after Skip.")
                run_adb(["shell", "screencap", "-p", f"/sdcard/cycle_{i}_welcome_error.png"])
                run_adb(["pull", f"/sdcard/cycle_{i}_welcome_error.png", f"scratch/cycle_{i}_welcome_error.png"])
                raise Exception("Welcome screen not detected.")

            # Enter Email
            print("Entering email...")
            if not enter_text_in_field(0, "testuser@cricup.com"):
                raise Exception("Failed to enter email.")
                
            # Enter Password
            print("Entering password...")
            if not enter_text_in_field(1, "Password123!"):
                raise Exception("Failed to enter password.")
                
            # Tap Sign In
            print("Tapping Sign In button...")
            if not tap_node_by_text("Sign In"):
                # Fallback to coordinates if node finding fails
                print("Sign In node not found by text, using coordinates...")
                run_adb(["shell", "input", "tap", "540", "1727"])
            time.sleep(7.0)
            
            # Verify login by checking for dashboard keywords
            print("Verifying login...")
            logged_in = False
            for attempt in range(5):
                if check_screen_text("scorer dashboard") or check_screen_text("admin-cricup") or check_screen_text("dashboard"):
                    logged_in = True
                    break
                time.sleep(1.5)
                
            if not logged_in:
                print(f"ERROR in Cycle {i}: Dashboard not loaded after login.")
                run_adb(["shell", "screencap", "-p", f"/sdcard/cycle_{i}_login_error.png"])
                run_adb(["pull", f"/sdcard/cycle_{i}_login_error.png", f"scratch/cycle_{i}_login_error.png"])
                raise Exception("Dashboard not detected.")
            
            print(f"Cycle {i}: Login Successful!")
            
            # Tap Logout
            print("Tapping Logout...")
            if not tap_node_by_text("Logout"):
                print("Logout node not found by text, using coordinates...")
                run_adb(["shell", "input", "tap", "1017", "210"])
            time.sleep(4.0)
            
            # Verify logout
            logged_out = False
            for attempt in range(5):
                if check_screen_text("welcome back") or check_screen_text("continue with google"):
                    logged_out = True
                    break
                time.sleep(1.5)
                
            if not logged_out:
                print(f"ERROR in Cycle {i}: Welcome Back screen not loaded after logout.")
                run_adb(["shell", "screencap", "-p", f"/sdcard/cycle_{i}_logout_error.png"])
                run_adb(["pull", f"/sdcard/cycle_{i}_logout_error.png", f"scratch/cycle_{i}_logout_error.png"])
                raise Exception("Logout verification failed.")
                
            print(f"Cycle {i}: Logout Successful!")
            success_count += 1
            
            # Force stop at end of cycle for clean setup
            run_adb(["shell", "am", "force-stop", "com.cricup"])
            time.sleep(1.0)
            
        except Exception as e:
            print(f"Cycle {i} failed with error: {e}")
            # Try to force stop on error
            run_adb(["shell", "am", "force-stop", "com.cricup"])
            break
            
    print(f"\n=================== RESULTS ===================")
    print(f"Conducted cycles: {i if success_count < total_cycles else total_cycles}")
    print(f"Successful cycles: {success_count} / {total_cycles}")
    if success_count == total_cycles:
        print("ALL 20 CYCLES COMPLETED SUCCESSFULLY!")
    else:
        print("VERIFICATION FAILED.")

if __name__ == "__main__":
    main()
