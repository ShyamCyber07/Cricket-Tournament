import subprocess
import time
import os
import re
import sys
import json
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\832a7ec0-18bd-4949-8d54-9da5a615c7ad"
CREDS_PATH = r"c:\Users\praja\Desktop\Cricket\scratch\prod_credentials.json"

def run_adb(args):
    cmd = [ADB] + args
    try:
        res = subprocess.run(cmd, capture_output=True, timeout=15)
        return res.stdout.decode('utf-8', errors='ignore')
    except subprocess.TimeoutExpired:
        print(f"WARNING: ADB command timed out: {' '.join(cmd)}")
        return ""

def capture_screen(filename):
    dest = os.path.join(ARTIFACTS_DIR, filename)
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot: {filename}")

def check_keyboard_and_dismiss():
    dumpsys = run_adb(["shell", "dumpsys", "input_method"])
    if "mInputShown=true" in dumpsys:
        print("Keyboard is shown, dismissing...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.5)

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
        time.sleep(1.5)
    return ""

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
            if len(nodes) > 0:
                if index < len(nodes):
                    bounds = nodes[index].get('bounds')
                    m = re.findall(r'\d+', bounds)
                    if len(m) == 4:
                        x1, y1, x2, y2 = map(int, m)
                        return (x1 + x2) // 2, (y1 + y2) // 2
        except Exception as e:
            print("Error parsing XML:", e)
        time.sleep(1.5)
    return None

def get_node_center_by_class(class_name, index=0, retries=5):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            continue
        try:
            root = ET.fromstring(xml_content)
            nodes = []
            for node in root.iter('node'):
                if node.get('class') == class_name:
                    nodes.append(node)
            if len(nodes) > 0:
                if index < len(nodes):
                    bounds = nodes[index].get('bounds')
                    m = re.findall(r'\d+', bounds)
                    if len(m) == 4:
                        x1, y1, x2, y2 = map(int, m)
                        return (x1 + x2) // 2, (y1 + y2) // 2
        except Exception as e:
            print("Error parsing XML:", e)
        time.sleep(1.5)
    return None

def check_screen_text(text_query, retries=3):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if text_query.lower() in xml_content.lower():
            return True
        if retries > 1:
            time.sleep(1.5)
    return False

def tap_node_by_text(text, index=0, wait_secs=3):
    coords = get_node_center_by_text(text, index)
    if coords:
        print(f"Tapping '{text}' at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    return False

def enter_text_in_field(field_index, text_val, wait_secs=1):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        # Clear field using backspaces
        clear_keys = ["123"] + ["67"] * 25
        run_adb(["shell", "input", "keyevent"] + clear_keys)
            
        escaped_val = text_val.replace(" ", "%s")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(wait_secs)
        return True
    return False

def run_smoke_test():
    print("\n=== STARTING RELEASE SMOKE TEST ON PHYSICAL DEVICE ===")
    
    # 1. Load credentials
    if not os.path.exists(CREDS_PATH):
        print(f"ERROR: Credentials file not found at {CREDS_PATH}")
        sys.exit(1)
    with open(CREDS_PATH, "r") as f:
        creds = json.load(f)
        
    email = creds["email"]
    password = creds["password"]
    username = creds["username"]
    print(f"Loaded smoke test credentials for user: {email}")
    
    print("Clearing com.cricup app data for a clean login smoke test...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(1.5)
    
    print("Launching app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    
    print("Waiting for Login screen or Onboarding...")
    login_screen_loaded = False
    for _ in range(12):
        if check_screen_text("Skip"):
            print("Onboarding screen detected, tapping Skip...")
            tap_node_by_text("Skip")
            time.sleep(2)
        if check_screen_text("Sign In") or check_screen_text("Sign Up"):
            login_screen_loaded = True
            break
        time.sleep(1.5)
        
    if not login_screen_loaded:
        print("ERROR: Login screen did not load.")
        capture_screen("smoke_failed_login_load.png")
        sys.exit(1)
        
    capture_screen("smoke_0_login_screen.png")
    
    # Sign In
    print("Entering email and password...")
    enter_text_in_field(0, email)
    enter_text_in_field(1, password)
    check_keyboard_and_dismiss()
    
    capture_screen("smoke_1_login_filled.png")
    print("Tapping Sign In...")
    tap_node_by_text("Sign In")
    time.sleep(6)
    
    # Complete Profile if requested
    if check_screen_text("Complete Profile"):
        print("Completing profile details...")
        enter_text_in_field(0, username)
        enter_text_in_field(1, "Smoke Scorer")
        check_keyboard_and_dismiss()
        print("Performing scroll to reveal Save and Continue...")
        run_adb(["shell", "input", "swipe", "500", "1500", "500", "800", "300"])
        time.sleep(1.5)
        capture_screen("smoke_2_complete_profile.png")
        tap_node_by_text("Save and Continue")
        time.sleep(6)
        
    # Verify Dashboard
    print("Verifying Scorer Dashboard loaded...")
    if not check_screen_text("Scorer Dashboard"):
        print("ERROR: Dashboard did not load.")
        capture_screen("smoke_failed_dashboard.png")
        sys.exit(1)
        
    capture_screen("smoke_3_dashboard_loaded.png")
    print("SUCCESS: Dashboard loaded successfully!")
    
    # Create Team
    print("Navigating to Team Management...")
    print("Scrolling down to reveal Teams action card...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2)
    # Quick action text "Team Management"
    if not tap_node_by_text("Team Management"):
        print("ERROR: Failed to tap on Teams action card.")
        sys.exit(1)
        
    time.sleep(3)
    if not check_screen_text("My Teams"):
        print("ERROR: Failed to load Team Management Screen.")
        capture_screen("smoke_failed_teams.png")
        sys.exit(1)
        
    capture_screen("smoke_4_team_management.png")
    
    print("Tapping Add Team FAB...")
    # Tap the FAB button by its description
    if not tap_node_by_text("Add Team FAB"):
        print("FAB tap by text failed, trying dynamic coordinates...")
        # Look for FloatingActionButton or Button at bottom right
        # Bottom right FAB is usually around (940, 2080) on width 1080
        run_adb(["shell", "input", "tap", "940", "2080"])
        time.sleep(2)
        
    if not check_screen_text("Create Team"):
        print("ERROR: Create Team dialog did not open.")
        capture_screen("smoke_failed_create_dialog.png")
        sys.exit(1)
        
    team_name = f"Team {username}"
    print(f"Entering team name: {team_name}...")
    enter_text_in_field(0, team_name)
    check_keyboard_and_dismiss()
    
    capture_screen("smoke_5_create_team_filled.png")
    print("Tapping Create...")
    tap_node_by_text("Create")
    time.sleep(4)
    
    if not check_screen_text(team_name):
        print(f"ERROR: Created team '{team_name}' is not listed.")
        capture_screen("smoke_failed_team_listing.png")
        sys.exit(1)
        
    capture_screen("smoke_6_team_created.png")
    print("SUCCESS: Team created successfully!")
    
    # Go back to Dashboard
    print("Navigating back to Dashboard...")
    run_adb(["shell", "input", "keyevent", "4"]) # Back button
    time.sleep(2)
    
    # Open profile
    print("Opening Profile Screen...")
    print("Tapping user avatar at (100, 150)...")
    run_adb(["shell", "input", "tap", "100", "150"])
    time.sleep(4)
    
    if not check_screen_text("PROFILE"):
        print("ERROR: Failed to navigate to Profile Screen.")
        capture_screen("smoke_failed_profile.png")
        sys.exit(1)
        
    capture_screen("smoke_7_profile_loaded.png")
    print("SUCCESS: Profile Screen loaded successfully!")
    
    print("\n=== SMOKE TEST SUCCESSFULLY COMPLETED ===")

if __name__ == "__main__":
    run_smoke_test()
