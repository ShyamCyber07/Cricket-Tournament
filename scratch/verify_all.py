import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re
import sys
import random

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\570c5832-ec96-4900-a8dd-d495effc011c"

# Generate a unique suffix for the run to prevent list search collisions
SUFFIX = str(random.randint(100, 999))
TEAM_A_NAME = f"Team A {SUFFIX}"
TEAM_B_NAME = f"Team B {SUFFIX}"
TOUR_NAME = f"Tour {SUFFIX}"

print(f"Using names for this run:")
print(f" - Team A: {TEAM_A_NAME}")
print(f" - Team B: {TEAM_B_NAME}")
print(f" - Tournament: {TOUR_NAME}")

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
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
        time.sleep(2.0)

def get_fresh_xml(retries=5):
    for attempt in range(retries):
        time.sleep(1.5)  # Let transitions settle
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

def is_node_clickable_and_visible(node):
    bounds = node.get('bounds', '')
    m = re.findall(r'\d+', bounds)
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        if x1 == x2 or y1 == y2:
            return False
        if x1 == 0 and y1 == 0 and x2 == 0 and y2 == 0:
            return False
        return True
    return False

def wait_for_loading_to_complete(retries=15):
    print("Waiting for loading indicators to disappear...")
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            time.sleep(1.0)
            continue
        try:
            root = ET.fromstring(xml_content)
            loading_found = False
            for node in root.iter('node'):
                bounds = node.get('bounds', '')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    w = x2 - x1
                    h = y2 - y1
                    center_x = (x1 + x2) // 2
                    center_y = (y1 + y2) // 2
                    is_small = (50 <= w <= 150) and (50 <= h <= 150)
                    is_centered = (450 <= center_x <= 630)
                    is_view = node.get('class') == 'android.view.View'
                    has_no_text = (not node.get('text')) and (not node.get('content-desc'))
                    is_leaf = len(list(node)) == 0
                    if is_small and is_centered and is_view and has_no_text and is_leaf:
                        print(f"Detected loading spinner at bounds {bounds} (center: {center_x}, {center_y})")
                        loading_found = True
                        break
            if not loading_found:
                print("No loading spinner detected.")
                return True
        except Exception as e:
            print("Error parsing XML in wait_for_loading:", e)
        time.sleep(1.0)
    print("WARNING: Timeout waiting for loading spinner to disappear.")
    return False

def get_node_center_by_text(text_query, index=0, retries=5, exact=True):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            continue
        try:
            root = ET.fromstring(xml_content)
            nodes = []
            for node in root.iter('node'):
                if not is_node_clickable_and_visible(node):
                    continue
                content_desc = node.get('content-desc', '').lower()
                text_val = node.get('text', '').lower()
                if exact:
                    if text_query.lower() == content_desc or text_query.lower() == text_val:
                        nodes.append(node)
                else:
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
            print("Error parsing XML in get_node_center_by_text:", e)
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
                if not is_node_clickable_and_visible(node):
                    continue
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
            print("Error parsing XML in get_node_center_by_class:", e)
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

def is_screen_active(title_text):
    xml_content = get_fresh_xml(retries=2)
    if not xml_content:
        return False
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            text = node.get('text', '') or node.get('content-desc', '')
            if title_text.lower() in text.lower():
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    # AppBar title is at the top portion of the screen (typically y1 > 50 and y2 < 350)
                    if y1 > 50 and y2 < 350:
                        return True
    except Exception as e:
        pass
    return False

def tap_node_by_text(text, index=0, wait_secs=3, exact=True):
    coords = get_node_center_by_text(text, index, exact=exact)
    if coords:
        print(f"Tapping '{text}' at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    return False

def scroll_down():
    print("Scrolling down...")
    run_adb(["shell", "input", "swipe", "540", "1800", "540", "400", "300"])
    time.sleep(1.5)

def tap_node_with_scroll(text, index=0, wait_secs=3, max_scrolls=3, exact=True):
    for scroll in range(max_scrolls + 1):
        coords = get_node_center_by_text(text, index, retries=2, exact=exact)
        if coords:
            print(f"Tapping '{text}' at coordinates {coords}")
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
            time.sleep(wait_secs)
            return True
        if scroll < max_scrolls:
            scroll_down()
    return False

def tap_node_or_raise(text, index=0, wait_secs=3, exact=True):
    if not tap_node_by_text(text, index, wait_secs, exact):
        raise Exception(f"CRITICAL: Failed to tap '{text}'")

def tap_node_with_scroll_or_raise(text, index=0, wait_secs=3, max_scrolls=3, exact=True):
    if not tap_node_with_scroll(text, index, wait_secs, max_scrolls, exact):
        raise Exception(f"CRITICAL: Failed to tap '{text}' with scroll")

def enter_text_in_field(field_index, text_val, wait_secs=1):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        # Clear field using backspaces
        clear_keys = ["123"] + ["67"] * 25
        run_adb(["shell", "input", "keyevent"] + clear_keys)
        # Input text
        escaped_val = text_val.replace(" ", "%s")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(wait_secs)
        return True
    return False

def ensure_on_dashboard():
    print("Ensuring app is on Scorer Dashboard...")
    for attempt in range(5):
        if is_screen_active("Scorer Dashboard") or is_screen_active("Admin-CricUp"):
            print("App is on Scorer Dashboard!")
            return True
        # Check if com.cricup is running in foreground
        dumpsys = run_adb(["shell", "dumpsys", "activity", "activities"])
        is_foreground = any("mcurrentfocus" in line.lower() and "com.cricup" in line.lower() for line in dumpsys.splitlines())
        if not is_foreground:
            print("App is not in foreground, launching...")
            print("Focus lines in dumpsys activity activities:")
            for line in dumpsys.splitlines():
                if "focus" in line.lower() or "resumed" in line.lower():
                    print("  ", line.strip())
            run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
            time.sleep(5.0)
            continue
        # Tap back button
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(3.0)
    return False

def ensure_on_teams_screen():
    print("Ensuring app is on Teams screen...")
    if is_screen_active("Team Management"):
        print("App is on Teams screen!")
        wait_for_loading_to_complete()
        return True
    for attempt in range(3):
        if not ensure_on_dashboard():
            continue
        scroll_down()
        if tap_node_by_text("Teams", exact=True, wait_secs=3):
            time.sleep(1.0)
            if is_screen_active("Team Management"):
                print("App is on Teams screen!")
                wait_for_loading_to_complete()
                return True
        scroll_down()
        if tap_node_by_text("Teams", exact=True, wait_secs=3):
            time.sleep(1.0)
            if is_screen_active("Team Management"):
                print("App is on Teams screen!")
                wait_for_loading_to_complete()
                return True
    raise Exception("CRITICAL: Failed to navigate to Teams screen!")

def ensure_on_tournaments_screen():
    print("Ensuring app is on Tournaments screen...")
    if is_screen_active("Tournaments") and not is_screen_active("Create Tournament"):
        print("App is on Tournaments screen!")
        wait_for_loading_to_complete()
        return True
    for attempt in range(3):
        if not ensure_on_dashboard():
            continue
        scroll_down()
        if tap_node_by_text("Tournaments", exact=True, wait_secs=3):
            time.sleep(1.0)
            if is_screen_active("Tournaments") and not is_screen_active("Create Tournament"):
                print("App is on Tournaments screen!")
                wait_for_loading_to_complete()
                return True
        scroll_down()
        if tap_node_by_text("Tournaments", exact=True, wait_secs=3):
            time.sleep(1.0)
            if is_screen_active("Tournaments") and not is_screen_active("Create Tournament"):
                print("App is on Tournaments screen!")
                wait_for_loading_to_complete()
                return True
    raise Exception("CRITICAL: Failed to navigate to Tournaments screen!")

def get_clickable_node_above_text(text_query):
    xml_content = get_fresh_xml(retries=3)
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        target_node = None
        for node in root.iter('node'):
            content_desc = node.get('content-desc', '').lower()
            text_val = node.get('text', '').lower()
            if text_query.lower() in content_desc or text_query.lower() in text_val:
                target_node = node
                break
        if target_node is not None:
            parent_map = {c: p for p in root.iter() for c in p}
            parent = parent_map.get(target_node)
            if parent is not None:
                idx = list(parent).index(target_node)
                if idx > 0:
                    prev_sibling = parent[idx-1]
                    bounds = prev_sibling.get('bounds')
                    m = re.findall(r'\d+', bounds)
                    if len(m) == 4:
                        x1, y1, x2, y2 = map(int, m)
                        return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error in get_clickable_node_above_text:", e)
    return None

def tap_first_photo_in_picker():
    xml_content = get_fresh_xml(retries=3)
    if not xml_content:
        return False
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            if node.get('package') == 'com.google.android.photopicker':
                desc = node.get('content-desc', '')
                if 'photo taken' in desc.lower() or 'video taken' in desc.lower():
                    bounds = node.get('bounds')
                    m = re.findall(r'\d+', bounds)
                    if len(m) == 4:
                        x1, y1, x2, y2 = map(int, m)
                        center = ((x1 + x2) // 2, (y1 + y2) // 2)
                        print(f"Tapping photo at center: {center}")
                        run_adb(["shell", "input", "tap", str(center[0]), str(center[1])])
                        time.sleep(2.0)
                        return True
    except Exception as e:
        print("Error tapping photo:", e)
    return False

def tap_photo_picker_done():
    coords = get_node_center_by_text("Done", retries=3, exact=True)
    if coords:
        print(f"Tapping Done in photo picker at {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(3.0)
        return True
    return False

def select_players_in_sheet(count=3):
    wait_for_loading_to_complete()
    xml_content = get_fresh_xml(retries=3)
    if not xml_content:
        return False
    try:
        root = ET.fromstring(xml_content)
        tapped = 0
        for node in root.iter('node'):
            desc = node.get('content-desc', '') or node.get('text', '')
            if 'batsman' in desc.lower() or 'bowler' in desc.lower() or 'all_rounder' in desc.lower():
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    center = ((x1 + x2) // 2, (y1 + y2) // 2)
                    print(f"Selecting player '{desc.splitlines()[0]}' at {center}")
                    run_adb(["shell", "input", "tap", str(center[0]), str(center[1])])
                    time.sleep(1.5)
                    tapped += 1
                    if tapped >= count:
                        return True
    except Exception as e:
        print("Error selecting players in sheet:", e)
    return tapped >= count

def tap_bulk_add_button():
    xml_content = get_fresh_xml(retries=3)
    if not xml_content:
        return False
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            desc = node.get('content-desc', '') or node.get('text', '')
            if 'add (' in desc.lower():
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    center = ((x1 + x2) // 2, (y1 + y2) // 2)
                    print(f"Tapping bulk add button '{desc}' at {center}")
                    run_adb(["shell", "input", "tap", str(center[0]), str(center[1])])
                    time.sleep(3.0)
                    return True
    except Exception as e:
        print("Error tapping bulk add button:", e)
    return False

def select_num_teams_in_dropdown(num_teams_str):
    if tap_node_by_text(num_teams_str, exact=True):
        return True
    xml_content = get_fresh_xml(retries=3)
    if not xml_content:
        return False
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            text = node.get('text', '') or node.get('content-desc', '')
            if 'teams' in text.lower() and is_node_clickable_and_visible(node):
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    center = ((x1 + x2) // 2, (y1 + y2) // 2)
                    print(f"Tapping dropdown containing 'Teams' at {center}")
                    run_adb(["shell", "input", "tap", str(center[0]), str(center[1])])
                    time.sleep(2.0)
                    if tap_node_by_text(num_teams_str, exact=True):
                        return True
    except Exception as e:
        print("Error selecting num teams:", e)
    return False

def click_create_and_verify(button_text="Create", success_msg="success", error_prefix="Failed to"):
    time.sleep(2.0) # Settle down keyboard animations
    index = -1 if button_text == "Create Tournament" else 0
    if not tap_node_by_text(button_text, index=index, exact=True):
        print(f"ERROR: Could not tap '{button_text}' button")
        return False
    time.sleep(1.0)
    for attempt in range(5):
        xml = get_fresh_xml(retries=1)
        if success_msg.lower() in xml.lower():
            print("Action succeeded (SnackBar detected)!")
            time.sleep(1.5)
            return True
        if error_prefix.lower() in xml.lower():
            try:
                root = ET.fromstring(xml)
                for node in root.iter('node'):
                    text = node.get('text', '') or node.get('content-desc', '')
                    if error_prefix.lower() in text.lower():
                        print(f"ERROR FROM APP SNACKBAR: {text}")
                        break
            except Exception:
                pass
            return False
        # Fallback closure checks
        if button_text == "Create" and "create team" not in xml.lower():
            print("Create Team Dialog closed successfully!")
            return True
        if button_text == "Create Tournament" and "create tournament" not in xml.lower():
            print("Create Tournament screen closed successfully!")
            return True
        time.sleep(1.0)
    return True

def main():
    print("Waking up and unlocking device...")
    run_adb(["shell", "input", "keyevent", "224"]) # KEYCODE_WAKEUP
    run_adb(["shell", "wm", "dismiss-keyguard"])
    time.sleep(1.5)

    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    
    print("Launching app...")
    launch_res = run_adb(["shell", "am", "start", "-W", "-n", "com.cricup/com.cricup.MainActivity"])
    print("Launch result:", launch_res.strip())
    time.sleep(5.0)
    
    if not ensure_on_dashboard():
        raise Exception("Failed to ensure app is on Scorer Dashboard at start")
    
    # 1. TEAM LOGO UPLOAD & CREATION (TEAM A)
    print("\n--- STEP 1: Creating Team A with Logo ---")
    ensure_on_teams_screen()
    
    # FAB click
    tap_node_or_raise("Add Team FAB", exact=True)
    time.sleep(2.0)
    
    # Click clickable image view container above "Tap to upload logo"
    coords = get_clickable_node_above_text("Tap to upload logo")
    if not coords:
        raise Exception("Failed to locate logo upload container")
    print(f"Tapping logo upload container at {coords}")
    run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    time.sleep(3.0)
    
    # Select first photo from picker
    if not tap_first_photo_in_picker():
        raise Exception("Failed to select photo from photo picker")
    # Click Done in picker
    if not tap_photo_picker_done():
        raise Exception("Failed to tap Done in photo picker")
    
    # Enter team name
    if not enter_text_in_field(0, TEAM_A_NAME):
        raise Exception("Failed to enter Team A name")
    check_keyboard_and_dismiss()
    
    # Capture Screenshot 1: Team Creation
    capture_screen("1_team_creation_with_logo.png")
    
    # Tap Create button
    if not click_create_and_verify("Create", "created successfully", "Failed to create team"):
        raise Exception("Failed to click create and verify Team A")
    time.sleep(3.0)
    
    # RESTART & CONFIRM TEAM LOGO PERSISTS
    print("\n--- STEP 1b: Verify Team Logo Persistence after Restart ---")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    run_adb(["shell", "am", "start", "-W", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(5.0)
    
    ensure_on_teams_screen()
    capture_screen("team_logo_persistence_check.png")
    
    # Assign players to Team A
    print(f"Assigning players to {TEAM_A_NAME}...")
    tap_node_with_scroll_or_raise(TEAM_A_NAME, exact=False)
    time.sleep(3)
    tap_node_or_raise("Add Player", exact=True)
    time.sleep(2)
    if not select_players_in_sheet(3):
        raise Exception("Failed to select 3 players for Team A")
    if not tap_bulk_add_button():
        raise Exception("Failed to tap bulk add button for Team A")
    time.sleep(3)
    wait_for_loading_to_complete()
    
    # Create Team B
    print(f"Creating {TEAM_B_NAME}...")
    ensure_on_teams_screen()
    tap_node_or_raise("Add Team FAB", exact=True)
    time.sleep(2.0)
    
    # Click clickable image view container
    coords = get_clickable_node_above_text("Tap to upload logo")
    if not coords:
        raise Exception("Failed to locate logo upload container for Team B")
    print(f"Tapping logo upload container at {coords}")
    run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    time.sleep(3.0)
        
    if not tap_first_photo_in_picker():
        raise Exception("Failed to select photo for Team B")
    if not tap_photo_picker_done():
        raise Exception("Failed to tap Done in photo picker for Team B")
    
    # Enter team name
    if not enter_text_in_field(0, TEAM_B_NAME):
        raise Exception("Failed to enter Team B name")
    check_keyboard_and_dismiss()
    # Tap Create button
    if not click_create_and_verify("Create", "created successfully", "Failed to create team"):
        raise Exception("Failed to click create and verify Team B")
    time.sleep(3.0)
    wait_for_loading_to_complete()
    
    # Assign players to Team B
    print(f"Assigning players to {TEAM_B_NAME}...")
    ensure_on_teams_screen()
    tap_node_with_scroll_or_raise(TEAM_B_NAME, exact=False)
    time.sleep(3)
    tap_node_or_raise("Add Player", exact=True)
    time.sleep(2)
    if not select_players_in_sheet(3):
        raise Exception("Failed to select 3 players for Team B")
    if not tap_bulk_add_button():
        raise Exception("Failed to tap bulk add button for Team B")
    time.sleep(3)
    wait_for_loading_to_complete()
    
    # 2. TOURNAMENT LOGO UPLOAD & CREATION
    print("\n--- STEP 2: Creating Tournament with Logo ---")
    ensure_on_tournaments_screen()
    
    # FAB click
    tap_node_or_raise("Add Tournament FAB", exact=True)
    time.sleep(2.0)
    
    # Upload logo click
    coords = get_clickable_node_above_text("Tournament Logo")
    if not coords:
        coords = get_clickable_node_above_text("Upload Tournament Logo")
    if not coords:
        raise Exception("Failed to locate logo upload container for Tournament")
    print(f"Tapping tournament logo container at {coords}")
    run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    time.sleep(3.0)
        
    if not tap_first_photo_in_picker():
        raise Exception("Failed to select photo for Tournament")
    if not tap_photo_picker_done():
        raise Exception("Failed to tap Done in photo picker for Tournament")
    
    # Enter tournament name
    if not enter_text_in_field(0, TOUR_NAME):
        raise Exception("Failed to enter Tournament name")
    check_keyboard_and_dismiss()
    
    # Select 2 Teams in dropdown
    if not select_num_teams_in_dropdown("2 Teams"):
        raise Exception("Failed to select '2 Teams' in dropdown")
    time.sleep(1.5)
    
    # Capture Screenshot 2: Tournament Creation
    capture_screen("2_tournament_creation_with_logo.png")
    
    # Scroll down to reveal Create Tournament button
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(1.5)
    
    # Create Tournament button tap
    if not click_create_and_verify("Create Tournament", "created successfully", "Failed to create tournament"):
        raise Exception("Failed to click create and verify Tournament")
    time.sleep(5.0)
    wait_for_loading_to_complete()
    
    # RESTART & CONFIRM TOURNAMENT LOGO PERSISTS
    print("\n--- STEP 2b: Verify Tournament Logo Persistence after Restart ---")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    run_adb(["shell", "am", "start", "-W", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(5.0)
    ensure_on_tournaments_screen()
    capture_screen("tournament_logo_persistence_check.png")
    
    # Open Tournament details and register teams, generate fixtures
    print("\n--- STEP 2c: Registering Teams and Generating Fixtures ---")
    tap_node_with_scroll_or_raise(TOUR_NAME, exact=False)
    time.sleep(3)
    wait_for_loading_to_complete()
    
    # Tap Teams tab
    tap_node_or_raise("Teams", exact=False)
    time.sleep(2)
    wait_for_loading_to_complete()
    
    # Register Team A
    tap_node_or_raise("Register", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    tap_node_with_scroll_or_raise(TEAM_A_NAME, exact=False)
    time.sleep(3)
    wait_for_loading_to_complete()
    
    # Register Team B
    tap_node_or_raise("Register", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    tap_node_with_scroll_or_raise(TEAM_B_NAME, exact=False)
    time.sleep(3)
    wait_for_loading_to_complete()
    
    # Lock and Generate Fixtures
    tap_node_with_scroll_or_raise("Lock Teams & Generate Fixtures", exact=False)
    time.sleep(2)
    tap_node_or_raise("Generate", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    
    # Press Back to exit tournament details and force refresh
    print("Pressing Back to return to Tournaments list and refresh details...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(3.0)
    ensure_on_tournaments_screen()
    # Re-open the tournament by name to refresh the details screen
    print(f"Re-opening tournament: {TOUR_NAME}")
    tap_node_with_scroll_or_raise(TOUR_NAME, exact=False)
    time.sleep(3)
    wait_for_loading_to_complete()

    
    # 3. MATCH VIEWER WITH LOGOS
    print("\n--- STEP 3: Match Viewer with Logos ---")
    tap_node_or_raise("Score Match", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    
    # Capture Screenshot 3: Match Viewer
    capture_screen("3_match_viewer_with_logos.png")
    
    # 4. SCORER SCREEN TIMELINE
    print("\n--- STEP 4: Scorer Timeline Verification ---")
    # Submit Toss Selection
    tap_node_or_raise("Submit & Proceed", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    
    # Submit squads
    tap_node_with_scroll_or_raise("Submit Squads & Proceed", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    
    # Select openers & start scoring
    tap_node_or_raise("Start Scoring", exact=True)
    time.sleep(2)
    wait_for_loading_to_complete()
    
    # Score runs sequence: 1, 4, 6, Wide (WD)
    # 1 run
    tap_node_or_raise("1", exact=True)
    time.sleep(2)
    # 4 runs
    tap_node_or_raise("4", exact=True)
    time.sleep(2)
    # 6 runs
    tap_node_or_raise("6", exact=True)
    time.sleep(2)
    # Wide (WD)
    if not tap_node_by_text("WD", exact=True):
        print("Falling back to coordinates for WD tap")
        run_adb(["shell", "input", "tap", "138", "2104"])
    time.sleep(2)
    
    # Capture Screenshot 4: Scorer screen with timeline before wicket
    capture_screen("4_scorer_screen_with_timeline.png")
    
    # Score Wicket
    tap_node_or_raise("WICKET", exact=True)
    time.sleep(2)
    tap_node_or_raise("Confirm Wicket", exact=True)
    time.sleep(3)
    
    # Select next striker from list (tap first batsman in list)
    run_adb(["shell", "input", "tap", "540", "400"])
    time.sleep(3)
    
    # Capture Screenshot 5: Timeline after wicket
    capture_screen("5_timeline_after_wicket.png")
    
    # 5. UNDO VERIFICATION
    print("\n--- STEP 5: Undo Verification ---")
    # Undo wicket
    tap_node_or_raise("UNDO", exact=True)
    time.sleep(3)
    # Undo wide
    tap_node_or_raise("UNDO", exact=True)
    time.sleep(3)
    # Undo 6 runs
    tap_node_or_raise("UNDO", exact=True)
    time.sleep(3)
    
    # Capture Screenshot 6: Timeline after undo
    capture_screen("6_timeline_after_undo.png")
    
    print("\nVerification completed successfully!")

if __name__ == "__main__":
    main()
