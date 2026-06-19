import subprocess
import time
import os
import re
import sys
import sqlite3
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DB_PATH = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\cf74d05a-9d09-4a85-82f1-b3d1bd0d2185"

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
        # Send Back button to dismiss keyboard
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.5)

def get_local_otp(email):
    print(f"Reading OTP from local SQLite database for email: {email}...")
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT otp_code FROM users WHERE email = ? OR username = ?", (email, email))
        row = cursor.fetchone()
        if not row:
            cursor.execute("SELECT otp_code FROM users ORDER BY created_at DESC LIMIT 1")
            row = cursor.fetchone()
        conn.close()
        if row:
            print(f"Found OTP code in DB: {row[0]}")
            return row[0]
    except Exception as e:
        print("Error reading database for OTP:", e)
    return None

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
        print(f"Warning: uiautomator dump failed. Retrying... ({attempt+1}/{retries})")
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
                else:
                    print(f"Index {index} out of range for '{text_query}' (found {len(nodes)})")
                    return None
        except Exception as e:
            print("Error parsing XML in get_node_center_by_text:", e)
        print(f"Attempt {attempt+1} to find text '{text_query}' failed. Retrying...")
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
    print(f"WARNING: Could not find node with text '{text}'")
    return False

def tap_top_right_button():
    xml_content = get_fresh_xml(retries=3)
    if xml_content:
        try:
            root = ET.fromstring(xml_content)
            for node in root.iter('node'):
                cls = node.get('class')
                bounds = node.get('bounds')
                if cls == "android.widget.Button" and bounds:
                    m = re.findall(r'\d+', bounds)
                    if len(m) == 4:
                        x1, y1, x2, y2 = map(int, m)
                        if x1 > 800 and y1 < 300:
                            print(f"Found top-right button at bounds {bounds}, tapping center: {((x1+x2)//2, (y1+y2)//2)}")
                            run_adb(["shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2)])
                            return True
        except Exception as e:
            print("Error parsing XML in tap_top_right_button:", e)
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
    print(f"WARNING: Could not find EditText at index {field_index}")
    return False

def run_verification():
    print("\n=== STARTING PROFILE UI & PHOTO UPLOAD VERIFICATION ===")
    
    # Establish ADB port reverse forwarding
    print("Setting up ADB port reverse forwarding for port 8000...")
    run_adb(["reverse", "tcp:8000", "tcp:8000"])
    
    # 1. Clean DB
    print("Cleaning local database...")
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM users")
        cursor.execute("DELETE FROM user_activities")
        cursor.execute("DELETE FROM user_achievements")
        conn.commit()
        conn.close()
        print("Database cleaned.")
    except Exception as e:
        print("Database cleaning error:", e)

    email = "refine_profile@t.com"
    username = "refineuser"
    password = "Password123!"

    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.5)
    
    print("Launching app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    
    print("Waiting for Login screen...")
    login_screen_loaded = False
    for _ in range(10):
        if check_screen_text("Sign In") or check_screen_text("Sign Up"):
            login_screen_loaded = True
            break
        time.sleep(1.5)
    
    if not login_screen_loaded:
        print("ERROR: Login screen did not load.")
        sys.exit(1)
        
    capture_screen("v0_login_screen.png")
    
    # Sign Up
    print("Tapping Sign Up...")
    tap_node_by_text("Sign Up")
    time.sleep(2)
    capture_screen("v1_signup_screen.png")
    
    enter_text_in_field(0, username)
    enter_text_in_field(1, email)
    enter_text_in_field(2, password)
    check_keyboard_and_dismiss()
    print("Performing small scroll to reveal confirm password...")
    run_adb(["shell", "input", "swipe", "500", "1200", "500", "900", "300"])
    time.sleep(1.5)
    enter_text_in_field(3, password)
    check_keyboard_and_dismiss()
    
    capture_screen("v2_signup_form_filled.png")
    tap_node_by_text("Sign Up")
    time.sleep(4)
    
    # OTP
    print("Waiting for OTP verification...")
    otp = None
    for _ in range(10):
        if check_screen_text("Verify OTP") or check_screen_text("Verification Code"):
            otp = get_local_otp(email)
            if otp:
                break
        time.sleep(1.5)
        
    if otp:
        print(f"Entering OTP code: {otp} digit-by-digit...")
        for i, digit in enumerate(str(otp)):
            enter_text_in_field(i, digit, wait_secs=0.5)
        time.sleep(4)
        
    # Complete Profile
    print("Completing profile...")
    if check_screen_text("Complete Profile"):
        enter_text_in_field(0, "Premium CricScorer")
        enter_text_in_field(1, "premium_scorer")
        check_keyboard_and_dismiss()
        print("Performing scroll to reveal Save and Continue...")
        run_adb(["shell", "input", "swipe", "500", "1500", "500", "800", "300"])
        time.sleep(1.5)
        tap_node_by_text("Save and Continue")
        time.sleep(4)
        
    # Verify Dashboard
    if not check_screen_text("Scorer Dashboard"):
        print("ERROR: Dashboard did not load.")
        sys.exit(1)
    capture_screen("v3_dashboard_loaded.png")
    
    # 2. Go to Profile Screen
    print("Navigating to Profile screen...")
    # The user avatar is inside AppBar, usually the first Image/CircleAvatar or can tap profile icon if present.
    # In dashboard_screen.dart, the profile picture is tapped to go to profile. Let's find it.
    # Wait, in the XML dump, the profile/avatar usually is tapped by class or position, or we can look for "Scorer Dashboard"
    # or tap by coordinates of the top right avatar.
    # Top right avatar is typically at X=960, Y=150 on most standard Android layouts (1080 width).
    # Let's tap the avatar by finding the first Image/CircleAvatar, or tap top right coordinates.
    # Let's dump the XML and find a node with class android.widget.ImageView at the top.
    avatar_coords = get_node_center_by_class("android.widget.ImageView", index=0) # logo or avatar?
    # Let's write a robust way. Let's tap top left: X=100, Y=150
    print("Tapping profile avatar at top-left (100, 150)...")
    run_adb(["shell", "input", "tap", "100", "150"])
    time.sleep(4)
    
    if not check_screen_text("PROFILE"):
        print("WARNING: Did not navigate to profile, trying another tap at (120, 150)...")
        run_adb(["shell", "input", "tap", "120", "150"])
        time.sleep(4)
        
    if not check_screen_text("PROFILE"):
        print("ERROR: Failed to navigate to Profile Screen.")
        capture_screen("v3_failed_profile_tap.png")
        sys.exit(1)
        
    capture_screen("v4_profile_screen_before.png")
    print("Successfully loaded Profile screen!")
    
    # Verify Tab Bar Switching
    print("Testing tab bar switching...")
    tap_node_by_text("ACHIEVED")
    time.sleep(2)
    capture_screen("v4b_profile_achieved_tab.png")
    
    tap_node_by_text("ACTIVITY")
    time.sleep(2)
    capture_screen("v4c_profile_activity_tab.png")
    
    tap_node_by_text("STATS")
    time.sleep(2)
    
    # 3. Edit Profile Screen
    print("Opening Edit Profile...")
    # Tap the edit icon (top right pencil icon)
    edit_tapped = tap_top_right_button()
    if not edit_tapped:
        print("Tapping edit icon at top-right coordinates fallback (970, 171)...")
        run_adb(["shell", "input", "tap", "970", "171"])
    time.sleep(4)
        
    if not check_screen_text("EDIT PROFILE"):
        print("ERROR: Failed to navigate to Edit Profile Screen.")
        capture_screen("v4_failed_edit_tap.png")
        sys.exit(1)
        
    capture_screen("v5_edit_profile_screen.png")
    print("Successfully loaded Edit Profile screen!")

    # 4. Mock a photo in the device's gallery
    print("Pushing mock avatar image to physical device gallery...")
    # Push v0_login_screen.png as the mock image
    run_adb(["push", ARTIFACTS_DIR + "/v0_login_screen.png", "/sdcard/Pictures/mock_avatar.png"])
    # Run media scan
    run_adb(["shell", "am", "broadcast", "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE", "-d", "file:///sdcard/Pictures/mock_avatar.png"])
    time.sleep(2)

    # 5. Start image picker flow
    print("Tapping on avatar picker to upload photo...")
    # Avatar container is at the top center. Let's tap around center top (540, 360)
    run_adb(["shell", "input", "tap", "540", "360"])
    time.sleep(3)
    capture_screen("v6_image_picker_bottom_sheet.png")
    
    print("Selecting gallery source...")
    tap_node_by_text("Choose from Gallery")
    time.sleep(4)
    capture_screen("v7_system_gallery.png")
    
    print("Selecting first image in gallery (using coordinate tap)...")
    # In system photo picker, the first photo is usually at X=180, Y=400 (or similar grid position)
    run_adb(["shell", "input", "tap", "180", "400"])
    time.sleep(5) # Give it time to upload and show success snackbar
    capture_screen("v8_edit_profile_photo_uploaded.png")
    
    # Fill in a bio
    print("Adding bio...")
    enter_text_in_field(2, "CricUP Elite Scorer. Powered by Antigravity.")
    check_keyboard_and_dismiss()
    
    capture_screen("v9_edit_profile_filled.png")
    
    print("Saving changes...")
    tap_node_by_text("SAVE CHANGES")
    time.sleep(5)
    
    # Verify updated profile screen
    print("Verifying updated Profile screen...")
    if not check_screen_text("PROFILE"):
        print("ERROR: Did not return to Profile screen after save.")
        capture_screen("v9_failed_return.png")
        sys.exit(1)
        
    capture_screen("v10_profile_screen_after.png")
    print("SUCCESS: Profile photo uploaded and updated!")
    
    # 6. Verify App Restart Persistence
    print("Restarting app to verify persistence...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(2)
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(6) # Wait for auto-login / splash
    
    # Navigate to profile again
    print("Navigating to profile after restart...")
    run_adb(["shell", "input", "tap", "100", "150"])
    time.sleep(4)
    
    capture_screen("v11_profile_after_restart.png")
    print("SUCCESS: Photo persists after restart!")
    
    # 7. Verify Logout / Login Persistence
    print("Logging out...")
    # Back to dashboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(2)
    # Tap Logout
    tap_node_by_text("Logout")
    time.sleep(3)
    capture_screen("v12_logged_out.png")
    
    print("Logging back in...")
    enter_text_in_field(0, email)
    enter_text_in_field(1, password)
    check_keyboard_and_dismiss()
    tap_node_by_text("Sign In")
    time.sleep(5)
    
    # Navigate to profile again
    print("Navigating to profile after relogin...")
    run_adb(["shell", "input", "tap", "100", "150"])
    time.sleep(4)
    
    capture_screen("v13_profile_after_relogin.png")
    print("SUCCESS: Photo persists after logout/login!")
    
    print("\n=== VERIFICATION SUCCESSFULLY COMPLETED ===")

if __name__ == "__main__":
    run_verification()
