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
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def capture_screen(filename):
    dest = os.path.join(ARTIFACTS_DIR, filename)
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot: {filename}")

def get_node_center_by_class(class_name, index=0):
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/curr.xml"])
    if not xml_content.strip() or "hierarchy" not in xml_content:
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

def main():
    # We are already on Team Management screen because step4 tapped FAB and we hit back or didn't complete.
    # Wait, let's make sure the dialog is closed or we press Back to clear it.
    print("Pressing back to make sure any dialog is dismissed...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.5)
    
    # 1. Tap Add Team FAB
    print("Tapping Add Team FAB...")
    run_adb(["shell", "input", "tap", "959", "2260"])
    time.sleep(2.0)
    
    # 2. Tap the upload circle at (540, 1100)
    print("Tapping logo upload circle...")
    run_adb(["shell", "input", "tap", "540", "1100"])
    time.sleep(3.0)
    
    # 3. Tap the first photo in gallery picker at (179, 1786)
    print("Selecting photo from gallery picker...")
    run_adb(["shell", "input", "tap", "179", "1786"])
    time.sleep(2.0)
    
    # 4. Type team name
    print("Entering team name 'Verify Team'...")
    enter_text_in_field(0, "Verify Team")
    
    # Capture filled dialog screen
    capture_screen("3_team_creation_filled.png")
    
    # 5. Tap 'Create' button at (712, 1600)
    print("Tapping Create button...")
    run_adb(["shell", "input", "tap", "712", "1600"])
    time.sleep(5.0)
    
    # Capture Team Management list
    capture_screen("4_team_created_list.png")
    
    # 6. Restart app to verify persistence
    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    
    print("Restarting app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(5.0)
    
    # Navigate to Teams again
    print("Scrolling down dashboard...")
    run_adb(["shell", "input", "swipe", "500", "1800", "500", "800", "300"])
    time.sleep(2.0)
    
    print("Tapping Teams card...")
    run_adb(["shell", "input", "tap", "207", "1815"])
    time.sleep(4.0)
    
    # Capture Team list after restart
    capture_screen("5_team_logo_persistence.png")
    print("Team Logo flow verification script completed!")

if __name__ == "__main__":
    main()
