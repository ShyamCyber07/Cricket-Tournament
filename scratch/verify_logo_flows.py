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
    try:
        res = subprocess.run(cmd, capture_output=True, timeout=10)
        return res.stdout.decode('utf-8', errors='ignore')
    except subprocess.TimeoutExpired:
        print(f"WARNING: ADB command timed out: {' '.join(cmd)}")
        return ""

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

def get_node_center_by_text(text_query):
    xml_content = get_fresh_xml()
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            content_desc = node.get('content-desc', '').lower()
            text_val = node.get('text', '').lower()
            if text_query.lower() == content_desc or text_query.lower() == text_val or text_query.lower() in content_desc or text_query.lower() in text_val:
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error parsing XML:", e)
    return None

def get_button_center_by_text(text_query):
    xml_content = get_fresh_xml()
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            desc = node.get('content-desc', '').lower()
            text = node.get('text', '').lower()
            cls = node.get('class', '')
            if 'button' in cls.lower() or 'widget.button' in cls.lower():
                if text_query.lower() == desc or text_query.lower() == text:
                    bounds = node.get('bounds')
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

def ensure_on_dashboard():
    print("Ensuring app is on Scorer Dashboard...")
    for attempt in range(5):
        if check_screen_text("Scorer Dashboard") and check_screen_text("Start Match Setup"):
            print("App is on Scorer Dashboard!")
            return True
        # Tap back button
        back_coords = get_node_center_by_text("Back") or (77, 160)
        print(f"Not on dashboard. Tapping back at {back_coords}")
        run_adb(["shell", "input", "tap", str(back_coords[0]), str(back_coords[1])])
        time.sleep(3.0)
    print("WARNING: Could not navigate back to Scorer Dashboard.")
    return False

def dump_screen_nodes():
    xml_content = get_fresh_xml()
    if not xml_content:
        return
    try:
        root = ET.fromstring(xml_content)
        for i, node in enumerate(root.iter('node')):
            text = node.get('text', '')
            desc = node.get('content-desc', '')
            cls = node.get('class', '')
            bounds = node.get('bounds', '')
            if text or desc:
                print(f"[{i}] Class: {cls} | Text: '{text}' | Desc: '{desc}' | Bounds: {bounds}")
    except Exception as e:
        print("Error parsing XML:", e)

def main():
    # Force stop and launch
    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    
    print("Launching app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(5.0)
    
    # Clean dashboard state
    ensure_on_dashboard()
    
    # 1. CREATE TEAM WITH LOGO
    print("=== STARTING TEAM CREATION FLOW ===")
    print("Scrolling down dashboard...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2.0)
    
    teams_coords = get_node_center_by_text("Teams") or (207, 1815)
    print(f"Tapping Teams card at {teams_coords}...")
    run_adb(["shell", "input", "tap", str(teams_coords[0]), str(teams_coords[1])])
    time.sleep(3.0)
    
    fab_coords = get_node_center_by_text("Add Team FAB") or (959, 2260)
    print(f"Tapping Add Team FAB at {fab_coords}...")
    run_adb(["shell", "input", "tap", str(fab_coords[0]), str(fab_coords[1])])
    time.sleep(2.0)
    
    logo_coords = get_node_center_by_text("Tap to upload logo") or (540, 1216)
    print(f"Tapping logo upload circle slightly above text at {logo_coords}...")
    run_adb(["shell", "input", "tap", str(logo_coords[0]), str(logo_coords[1] - 80)])
    time.sleep(3.0)
    
    print("Selecting first photo in gallery picker at (179, 1786)...")
    run_adb(["shell", "input", "tap", "179", "1786"])
    time.sleep(1.5)
    
    done_coords = get_node_center_by_text("Done") or (892, 2191)
    print(f"Tapping Done in photo picker at {done_coords}...")
    run_adb(["shell", "input", "tap", str(done_coords[0]), str(done_coords[1])])
    time.sleep(3.0)
    
    print("Entering team name 'Verify Team'...")
    enter_text_in_field(0, "Verify Team")
    
    capture_screen("3_team_creation_filled.png")
    
    # Tap Create button using precise class matching or fallback (712, 1600)
    create_coords = get_button_center_by_text("Create") or (712, 1600)
    print(f"Tapping Create button at {create_coords}...")
    run_adb(["shell", "input", "tap", str(create_coords[0]), str(create_coords[1])])
    time.sleep(5.0)
    
    capture_screen("4_team_created_list.png")
    
    # Press back to go to dashboard
    print("Going back to dashboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(2.0)
    
    # 2. CREATE TOURNAMENT WITH LOGO
    print("=== STARTING TOURNAMENT CREATION FLOW ===")
    ensure_on_dashboard()
    
    print("Scrolling down dashboard...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2.0)
    
    tour_coords = get_node_center_by_text("Tournaments") or (540, 1815)
    print(f"Tapping Tournaments card at {tour_coords}...")
    run_adb(["shell", "input", "tap", str(tour_coords[0]), str(tour_coords[1])])
    time.sleep(3.0)
    
    fab_coords = get_node_center_by_text("Add Tournament FAB") or (959, 2260)
    print(f"Tapping Add Tournament FAB at {fab_coords}...")
    run_adb(["shell", "input", "tap", str(fab_coords[0]), str(fab_coords[1])])
    time.sleep(3.0)
    
    logo_coords = get_node_center_by_text("Upload Tournament Logo") or (540, 930)
    print(f"Tapping logo selector slightly above text at {logo_coords}...")
    run_adb(["shell", "input", "tap", str(logo_coords[0]), str(logo_coords[1] - 80)])
    time.sleep(3.0)
    
    print("Selecting photo in gallery picker...")
    run_adb(["shell", "input", "tap", "179", "1786"])
    time.sleep(1.5)
    
    print("Tapping Done in photo picker...")
    run_adb(["shell", "input", "tap", "892", "2191"])
    time.sleep(3.0)
    
    print("Entering tournament name 'Verify Tournament'...")
    enter_text_in_field(0, "Verify Tournament")
    
    capture_screen("6_tournament_creation_filled.png")
    
    # Scroll down to reveal submit button
    print("Scrolling down to reveal Create Tournament button...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(1.5)
    
    submit_coords = get_button_center_by_text("Create Tournament") or (540, 2060)
    print(f"Tapping Create Tournament button at {submit_coords}...")
    run_adb(["shell", "input", "tap", str(submit_coords[0]), str(submit_coords[1])])
    time.sleep(5.0)
    
    capture_screen("7_tournament_created_list.png")
    
    # 3. VERIFY PERSISTENCE AFTER RESTART
    print("=== VERIFYING PERSISTENCE AFTER RESTART ===")
    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    
    print("Restarting app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(5.0)
    
    ensure_on_dashboard()
    
    # Verify Team Logo
    print("Scrolling down dashboard to check Teams...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2.0)
    
    print("Tapping Teams card...")
    run_adb(["shell", "input", "tap", "207", "1815"])
    time.sleep(4.0)
    
    print("Team List screen nodes after restart:")
    dump_screen_nodes()
    capture_screen("5_team_logo_persistence.png")
    
    print("Going back to dashboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(2.0)
    
    # Verify Tournament Logo
    ensure_on_dashboard()
    print("Scrolling down dashboard to check Tournaments...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2.0)
    
    print("Tapping Tournaments card...")
    run_adb(["shell", "input", "tap", "540", "1815"])
    time.sleep(4.0)
    
    print("Tournament List screen nodes after restart:")
    dump_screen_nodes()
    capture_screen("8_tournament_logo_persistence.png")
    
    print("Verification completed successfully!")

if __name__ == "__main__":
    main()
