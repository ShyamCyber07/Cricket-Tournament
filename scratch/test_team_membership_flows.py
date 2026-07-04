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

def capture_debug_screenshot(name):
    run_adb(["shell", "screencap", "-p", f"/sdcard/{name}.png"])
    run_adb(["pull", f"/sdcard/{name}.png", f"scratch/{name}.png"])
    print(f"Captured debug screenshot: scratch/{name}.png")

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

def get_node_center_by_text(text_query, index=0, retries=5, exact=False):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            continue
        try:
            root = ET.fromstring(xml_content)
            nodes = []
            for node in root.iter('node'):
                if node.get('class') == 'android.widget.EditText':
                    continue
                content_desc = node.get('content-desc', '').strip().lower()
                text_val = node.get('text', '').strip().lower()
                clean_query = text_query.strip().lower()
                if clean_query == content_desc or clean_query == text_val:
                    nodes.append(node)
            if not nodes and not exact:
                for node in root.iter('node'):
                    if node.get('class') == 'android.widget.EditText':
                        continue
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

def tap_node_by_text(text, index=0, wait_secs=3, exact=False):
    coords = get_node_center_by_text(text, index, exact=exact)
    if coords:
        time.sleep(1.0)
        print(f"Tapping '{text}' at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    print(f"WARNING: Could not find node with text '{text}'")
    return False


def scroll_to_text(text_query, max_swipes=15):
    for i in range(max_swipes):
        if check_screen_text(text_query, retries=1):
            print(f"Found '{text_query}' after {i} swipes.")
            return True
        print(f"Swiping up to find '{text_query}'... (swipe {i+1})")
        run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "400"])
        time.sleep(1.5)
    return False

def tap_join_for_team(team_name):
    if not scroll_to_text(team_name):
        print(f"ERROR: Could not scroll to team '{team_name}'")
        return False
    coords = get_node_center_by_text(team_name, exact=False)
    if coords:
        x, y = coords
        print(f"Found team '{team_name}' at {coords}. Tapping Join button at (880, {y})...")
        run_adb(["shell", "input", "tap", "880", str(y)])
        time.sleep(4.0)
        return True
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
        
        # Wait for keyboard to be shown, re-tapping if needed
        keyboard_ready = False
        for attempt in range(5):
            if is_keyboard_shown():
                keyboard_ready = True
                break
            print(f"Keyboard not ready yet, re-tapping field {field_index}... (attempt {attempt+1})")
            time.sleep(1.0)
            run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
            
        time.sleep(1.0)
        capture_debug_screenshot(f"field_{field_index}_after_focus")
        
        print("Clearing field...")
        clear_keys = ["123"] + ["67"] * 40
        run_adb(["shell", "input", "keyevent"] + clear_keys)
        time.sleep(1.5)
        capture_debug_screenshot(f"field_{field_index}_after_clear")
        
        print(f"Typing value into field {field_index}...")
        escaped_val = text_val.replace(" ", "%s").replace("!", "\\!")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(1.0)
        capture_debug_screenshot(f"field_{field_index}_after_type")
        
        # Dismiss keyboard so it does not block the next field or buttons
        check_keyboard_and_dismiss()
        capture_debug_screenshot(f"field_{field_index}_after_dismiss")
        return True
    print(f"WARNING: Could not find EditText at index {field_index}")
    return False

def login(email, password):
    print(f"Logging in as {email}...")
    # Email input
    if not enter_text_in_field(0, email):
        raise Exception("Failed to enter email.")
    # Password input
    if not enter_text_in_field(1, password):
        raise Exception("Failed to enter password.")
    # Dismiss keyboard before Sign In
    check_keyboard_and_dismiss()
    # Sign In
    if not tap_node_by_text("Sign In", exact=True):
        print("Sign In node not found by text, using coordinates...")
        run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(6.0)

    # Verify login
    logged_in = False
    for attempt in range(5):
        if check_screen_text("scorer dashboard") or check_screen_text("dashboard"):
            logged_in = True
            break
        time.sleep(1.5)
    if not logged_in:
        raise Exception(f"Login failed for {email}.")
    print("Login successful!")

def logout():
    print("Logging out...")
    if not tap_node_by_text("Logout", exact=True):
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
        raise Exception("Logout failed.")
    print("Logout successful!")

def go_back_to_dashboard():
    print("Going back to dashboard...")
    for attempt in range(4):
        if check_screen_text("Logout"):
            print("Successfully reached dashboard screen!")
            return True
        if check_screen_text("welcome back") or check_screen_text("continue with google"):
            print("WARNING: Popped too far and reached Login screen.")
            return False
            
        print(f"Not on dashboard yet. Tapping back arrow (77, 160)... (attempt {attempt+1})")
        run_adb(["shell", "input", "tap", "77", "160"])
        time.sleep(2.0)
        
        if check_screen_text("Logout"):
            print("Successfully reached dashboard screen!")
            return True
            
        print(f"Trying keyevent 4 fallback...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(2.0)
        
    raise Exception("Failed to return to dashboard after multiple attempts.")

def main():
    
    print("Force stopping LatinIME settings...")
    run_adb(["shell", "am", "force-stop", "com.google.android.inputmethod.latin"])
    
    print("Resetting app data...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)

    # Launch app
    print("Launching app...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(7.0)

    # Wait for app to load (either onboarding or login screen)
    print("Waiting for app to load...")
    loaded = False
    for _ in range(15):
        if check_screen_text("Skip") or check_screen_text("Welcome Back") or check_screen_text("Sign In"):
            loaded = True
            break
        time.sleep(1.0)
    
    if not loaded:
        print("WARNING: App did not load onboarding or login screen in time.")
    else:
        print("App loaded. Sleeping 3.0s for stabilization...")
        time.sleep(3.0)

    # Bypass onboarding if present
    if check_screen_text("Skip"):
        print("Onboarding screen detected. Bypassing onboarding...")
        tap_node_by_text("Skip")
        time.sleep(4.0)

    # --- STEP 1: Log in as Captain, create team ---
    login("captain@cricup.com", "Password123")

    # Open Teams screen
    print("Navigating to Team Management...")
    if not tap_node_by_text("Team Management"):
        raise Exception("Failed to navigate to Team Management")
    time.sleep(3.0)

    # Create Team
    print("Creating Team...")
    if not tap_node_by_text("Add Team FAB"):
        raise Exception("Failed to tap Add Team FAB")
    time.sleep(2.0)
    if not enter_text_in_field(0, "Test Automation Team"):
        raise Exception("Failed to enter team name")
    if not tap_node_by_text("Create", exact=True):
        raise Exception("Failed to tap Create")
    time.sleep(4.0)

    # Go back to Dashboard and logout
    go_back_to_dashboard()
    logout()

    # --- STEP 2: Log in as Player, explore teams, send join request, check pending ---
    login("player@cricup.com", "Password123")

    print("Navigating to Team Management...")
    if not tap_node_by_text("Team Management"):
        raise Exception("Failed to navigate to Team Management")
    time.sleep(3.0)

    print("Switching to Explore Teams tab...")
    switched = False
    for attempt in range(5):
        if tap_node_by_text("Explore Teams", wait_secs=2):
            if check_screen_text("Tap to join this team") or check_screen_text("No new teams") or check_screen_text("No teams found"):
                switched = True
                break
        print("Warning: Tab switch to Explore Teams not verified yet. Retrying...")
        time.sleep(1.0)
    if not switched:
        raise Exception("Failed to switch to Explore Teams tab")
    time.sleep(1.0)

    print("Searching for Test Automation Team...")
    if not enter_text_in_field(0, "Test Automation Team"):
        raise Exception("Failed to enter search query")
    time.sleep(3.0)

    print("Tapping Join on Test Automation Team...")
    if not tap_join_for_team("Test Automation Team"):
        raise Exception("Failed to tap Join button")

    print("Switching back to Joined Teams tab...")
    switched = False
    for attempt in range(5):
        if tap_node_by_text("Joined Teams", wait_secs=2):
            if check_screen_text("PENDING") or check_screen_text("You are not a member"):
                switched = True
                break
        print("Warning: Tab switch to Joined Teams not verified yet. Retrying...")
        time.sleep(1.0)
    if not switched:
        raise Exception("Failed to switch to Joined Teams tab")
    time.sleep(1.0)

    # Verify PENDING badge
    if not check_screen_text("PENDING"):
        raise Exception("Pending badge not found under Joined Teams!")
    print("Verified PENDING badge is displayed!")

    # Tap on team to verify pending dialog popup
    print("Tapping on pending team to verify dialog...")
    if not tap_node_by_text("Test Automation Team"):
        raise Exception("Failed to tap Test Automation Team")
    time.sleep(2.0)
    if not check_screen_text("Request Pending"):
        raise Exception("Request Pending dialog did not show up!")
    print("Verified Request Pending dialog shows up correctly!")
    if not tap_node_by_text("OK", exact=True):
        raise Exception("Failed to tap OK on pending dialog")
    time.sleep(2.0)

    # Go back to Dashboard and logout
    go_back_to_dashboard()
    logout()

    # --- STEP 3: Log in as Captain, approve join request, invite user, revoke invitation ---
    login("captain@cricup.com", "Password123")

    print("Navigating to Team Management...")
    if not tap_node_by_text("Team Management"):
        raise Exception("Failed to navigate to Team Management")
    time.sleep(3.0)

    # Tap team to view details
    print("Viewing Test Automation Team details...")
    if not tap_node_by_text("Test Automation Team"):
        raise Exception("Failed to tap Test Automation Team")
    time.sleep(3.0)

    # Switch to Members tab
    print("Switching to Members tab...")
    if not tap_node_by_text("Members"):
        raise Exception("Failed to tap Members tab")
    time.sleep(3.0)

    # Verify pending join request is listed
    if not check_screen_text("Pending Join Requests"):
        raise Exception("Pending Join Requests section not found!")
    print("Verified Pending Join Requests section shows up!")

    # Approve request
    print("Approving Player User request...")
    if not tap_node_by_text("Approve", exact=True):
        raise Exception("Failed to tap Approve")
    time.sleep(3.0)

    # Invite a user (testuser@cricup.com)
    print("Inviting testuser@cricup.com...")
    if not tap_node_by_text("Add Member", exact=True):
        raise Exception("Failed to tap Add Member")
    time.sleep(2.0)
    if not enter_text_in_field(0, "testuser@cricup.com"):
        raise Exception("Failed to enter email in Add Member dialog")
    if not tap_node_by_text("SEND INVITATION", exact=False):
        raise Exception("Failed to tap SEND INVITATION in Add Member dialog")
    time.sleep(4.0)

    # Verify invitation is under Sent Invitations section
    if not check_screen_text("Sent Invitations"):
        raise Exception("Sent Invitations section not found!")
    print("Verified Sent Invitations section shows up!")

    # Revoke invitation
    print("Revoking invitation...")
    if not tap_node_by_text("Revoke", exact=True):
        raise Exception("Failed to tap Revoke")
    time.sleep(3.0)

    # Go back and logout
    go_back_to_dashboard()
    logout()

    # --- STEP 4: Log in as Player, verify team is ACTIVE ---
    login("player@cricup.com", "Password123")

    print("Navigating to Team Management...")
    if not tap_node_by_text("Team Management"):
        raise Exception("Failed to navigate to Team Management")
    time.sleep(3.0)

    # Verify ACTIVE badge
    if not check_screen_text("ACTIVE"):
        raise Exception("Active badge not found under Joined Teams!")
    print("Verified ACTIVE badge is displayed!")

    # Tap team to verify details open successfully
    print("Tapping on active team to verify details open...")
    if not tap_node_by_text("Test Automation Team"):
        raise Exception("Failed to tap Test Automation Team")
    time.sleep(3.0)
    if not check_screen_text("Members") or not check_screen_text("Squad"):
        raise Exception("Team details did not load successfully!")
    print("Verified Team details page loaded successfully!")

    # Go back and logout
    go_back_to_dashboard()
    logout()

    print("\nALL AUTOMATED VERIFICATION FLOWS COMPLETED SUCCESSFULLY!")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Exception encountered: {e}")
        run_adb(["shell", "screencap", "-p", "/sdcard/error_screenshot.png"])
        run_adb(["pull", "/sdcard/error_screenshot.png", "scratch/error_screenshot.png"])
        print("Captured error screenshot to scratch/error_screenshot.png")
        raise
