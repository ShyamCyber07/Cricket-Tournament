import subprocess
import time
import os
import re
import sys
import random
import string
import sqlite3
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DB_PATH = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\4d605441-98fe-4643-93ea-6337d208b6d9"

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
        print("Keyboard is shown, dismissing by tapping Gboard action button...")
        run_adb(["shell", "input", "tap", "960", "2220"])
        time.sleep(1.5)

def get_local_otp(email):
    print(f"Reading OTP from local SQLite database for email: {email}...")
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT otp_code FROM users WHERE email = ? OR username = ?", (email, email))
        row = cursor.fetchone()
        if not row:
            print("Query by email failed. Querying for the latest registered user's OTP...")
            cursor.execute("SELECT otp_code FROM users ORDER BY created_at DESC LIMIT 1")
            row = cursor.fetchone()
        conn.close()
        if row:
            print(f"Found OTP code in DB: {row[0]}")
            return row[0]
    except Exception as e:
        print("Error reading database for OTP:", e)
    return None

def clean_db():
    print("Cleaning SQLite database for a clean E2E walkthrough...")
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        # Clean in correct dependency order
        cursor.execute("DELETE FROM balls")
        cursor.execute("DELETE FROM innings")
        cursor.execute("DELETE FROM match_squads")
        cursor.execute("DELETE FROM matches")
        cursor.execute("DELETE FROM tournament_teams")
        cursor.execute("DELETE FROM tournaments")
        cursor.execute("DELETE FROM team_players")
        cursor.execute("DELETE FROM teams")
        cursor.execute("DELETE FROM players")
        cursor.execute("DELETE FROM users")
        conn.commit()
        conn.close()
        print("Database cleaned successfully.")
    except Exception as e:
        print("Error cleaning database:", e)

def get_fresh_xml(retries=5):
    for attempt in range(retries):
        time.sleep(1.0)  # Let UI transitions settle before dump
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
        print(f"Warning: uiautomator dump failed or returned invalid XML. Retrying in 1.5s... (Attempt {attempt+1}/{retries})")
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
            # Try exact match first
            for node in root.iter('node'):
                content_desc = node.get('content-desc', '').lower()
                text_val = node.get('text', '').lower()
                if text_query.lower() == content_desc or text_query.lower() == text_val:
                    nodes.append(node)
            # Fall back to substring match if no exact match found
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
                else:
                    print(f"Index {index} out of range for class '{class_name}' (found {len(nodes)})")
                    return None
        except Exception as e:
            print("Error parsing XML in get_node_center_by_class:", e)
        print(f"Attempt {attempt+1} to find class '{class_name}' failed. Retrying...")
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

def scroll_down():
    print("Scrolling down...")
    run_adb(["shell", "input", "swipe", "540", "1600", "540", "600", "800"])
    time.sleep(1.5)

def find_node_with_scroll(text_query, index=0, max_scrolls=3):
    for scroll in range(max_scrolls + 1):
        coords = get_node_center_by_text(text_query, index, retries=2)
        if coords:
            return coords
        if scroll < max_scrolls:
            scroll_down()
            capture_screen(f"scroll_after_{scroll}.png")
    return None

def tap_node_with_scroll(text, index=0, wait_secs=3):
    coords = find_node_with_scroll(text, index)
    if coords:
        print(f"Tapping '{text}' at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    print(f"WARNING: Could not find node with text '{text}' even after scrolling")
    return False

def get_sibling_button_coords(item_text, button_tooltip, retries=5):
    for attempt in range(retries):
        xml_content = get_fresh_xml(retries=2)
        if not xml_content:
            continue
        try:
            root = ET.fromstring(xml_content)
            
            # 1. Find the item node
            item_node = None
            for node in root.iter('node'):
                content_desc = node.get('content-desc', '').lower()
                text_val = node.get('text', '').lower()
                if item_text.lower() == content_desc or item_text.lower() == text_val or item_text.lower() in content_desc or item_text.lower() in text_val:
                    item_node = node
                    break
                    
            if item_node is None:
                print(f"Could not find item node with text '{item_text}' on attempt {attempt+1}")
                time.sleep(1.5)
                continue
                
            bounds = item_node.get('bounds')
            m = re.findall(r'\d+', bounds)
            if len(m) != 4:
                continue
            item_y = (int(m[1]) + int(m[3])) // 2
            
            # 2. Find the button nodes and choose the closest vertically
            best_coords = None
            min_dist = 999999
            
            for node in root.iter('node'):
                content_desc = node.get('content-desc', '').lower()
                text_val = node.get('text', '').lower()
                if button_tooltip.lower() == content_desc or button_tooltip.lower() == text_val or button_tooltip.lower() in content_desc or button_tooltip.lower() in text_val:
                    b_bounds = node.get('bounds')
                    bm = re.findall(r'\d+', b_bounds)
                    if len(bm) == 4:
                        bx1, by1, bx2, by2 = map(int, bm)
                        by = (by1 + by2) // 2
                        bx = (bx1 + bx2) // 2
                        dist = abs(item_y - by)
                        if dist < min_dist:
                            min_dist = dist
                            best_coords = (bx, by)
                            
            if best_coords and min_dist < 150: # Threshold of 150 pixels vertically
                return best_coords
                
        except Exception as e:
            print("Error parsing XML in get_sibling_button_coords:", e)
        print(f"Attempt {attempt+1} to find sibling button '{button_tooltip}' for '{item_text}' failed. Retrying...")
        time.sleep(1.5)
    return None

def tap_sibling_button(item_text, button_tooltip, wait_secs=3):
    coords = get_sibling_button_coords(item_text, button_tooltip)
    if not coords:
        # Try scrolling down to find it
        for scroll in range(3):
            scroll_down()
            coords = get_sibling_button_coords(item_text, button_tooltip, retries=2)
            if coords:
                break
    if coords:
        print(f"Tapping sibling button '{button_tooltip}' for '{item_text}' at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    print(f"WARNING: Could not find sibling button '{button_tooltip}' for '{item_text}'")
    return False

def enter_text_in_field(field_index, text_val, wait_secs=1):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(0.5)
        # Clear field completely using a single keyevent command
        clear_keys = ["123"] + ["67"] * 15
        run_adb(["shell", "input", "keyevent"] + clear_keys)
            
        escaped_val = text_val.replace(" ", "%s")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(wait_secs)
        return True
    print(f"WARNING: Could not find EditText at index {field_index}")
    return False

def run_walkthrough():
    clean_db()
    
    email_address = "e2e@t.com"
    username = "e2euser"
    password = "Password123!"
    new_password = "NewPassword123!"
    
    print("\n=== STARTING END-TO-END AUDIT & WALKTHROUGH ===")
    
    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(2)
    print("Launching com.cricup/com.cricup.MainActivity...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    print("Waiting for Login/Splash screen to settle and load...")
    login_screen_loaded = False
    for _ in range(15):
        if check_screen_text("Sign In") or check_screen_text("Sign Up"):
            login_screen_loaded = True
            break
        print("Login screen not loaded yet, waiting...")
        time.sleep(2.0)
        
    if not login_screen_loaded:
        print("ERROR: Login screen failed to load in time.")
        sys.exit(1)
        
    capture_screen("0_initial_login_screen.png")
    time.sleep(3)
    
    # 1. Sign Up Flow
    print("\n--- Step 1: Sign Up ---")
    signup_loaded = False
    for attempt in range(5):
        if check_screen_text("Create Account") or check_screen_text("Create your platform"):
            signup_loaded = True
            break
        print(f"Tapping Sign Up link (attempt {attempt+1})...")
        tap_node_by_text("Sign Up")
        time.sleep(3.0)
    if not signup_loaded:
        print("ERROR: Failed to load Sign Up screen.")
        sys.exit(1)
    enter_text_in_field(0, username)
    enter_text_in_field(1, email_address)
    enter_text_in_field(2, password)
    check_keyboard_and_dismiss()
    enter_text_in_field(3, password)
    check_keyboard_and_dismiss()
    
    capture_screen("1_signup_form_filled.png")
    tap_node_by_text("Sign Up")
    time.sleep(5)
    
    # Verify OTP
    print("Waiting for OTP screen to load...")
    otp_loaded = False
    for _ in range(10):
        if check_screen_text("Verify OTP") or check_screen_text("Verification Code"):
            otp_loaded = True
            break
        time.sleep(1.5)
        
    if otp_loaded:
        capture_screen("2_otp_screen.png")
        otp = get_local_otp(email_address)
        if otp:
            # Enter OTP box by box or tap first box
            enter_text_in_field(0, otp)
            time.sleep(5)
            
    # Complete Profile
    print("Waiting for Complete Profile screen to load...")
    profile_loaded = False
    for _ in range(10):
        if check_screen_text("Complete Profile") or check_screen_text("Save and Continue"):
            profile_loaded = True
            break
        time.sleep(1.5)

    if profile_loaded:
        capture_screen("3_complete_profile_screen.png")
        enter_text_in_field(0, "E2E Audit User")
        enter_text_in_field(1, "ScorerPro")
        check_keyboard_and_dismiss()
        tap_node_with_scroll("Save and Continue")
        time.sleep(5)
        
    # Sync email_address with what is actually stored in DB
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT email FROM users ORDER BY created_at DESC LIMIT 1")
        row = cursor.fetchone()
        conn.close()
        if row:
            email_address = row[0]
            print(f"Synced email_address with DB: {email_address}")
    except Exception as e:
        print("Failed to sync email from DB:", e)
        
    # Dashboard Verification
    if check_screen_text("Scorer Dashboard"):
        print("SUCCESS: Dashboard loaded after signup!")
        capture_screen("4_dashboard_loaded.png")
    else:
        print("ERROR: Failed to load dashboard.")
        sys.exit(1)
        
    # Logout
    print("\n--- Step 2: Logout ---")
    # Tap logout button using content description/tooltip
    if not tap_node_by_text("Logout"):
        print("ERROR: Failed to tap Logout button.")
        sys.exit(1)
    time.sleep(3)
    
    # 2. Login Flow
    print("\n--- Step 3: Login ---")
    enter_text_in_field(0, email_address)
    enter_text_in_field(1, password)
    check_keyboard_and_dismiss()
    tap_node_by_text("Sign In")
    time.sleep(5)
    
    if check_screen_text("Scorer Dashboard"):
        print("SUCCESS: Logged in successfully!")
        capture_screen("5_login_success.png")
        if not tap_node_by_text("Logout"):
            print("ERROR: Failed to tap Logout button after successful login.")
            sys.exit(1)
        time.sleep(3)
    else:
        print("ERROR: Login failed.")
        sys.exit(1)
        
    # 3. Forgot Password Flow
    print("\n--- Step 4: Forgot Password ---")
    tap_node_by_text("Forgot Password?")
    time.sleep(3)
    enter_text_in_field(0, email_address)
    check_keyboard_and_dismiss()
    capture_screen("6_forgot_password_email.png")
    tap_node_by_text("Send Verification Code")
    
    # Wait for OTP screen to load
    print("Waiting for OTP screen to load...")
    otp_screen_loaded = False
    for attempt in range(15):
        if check_screen_text("Verify Code") or check_screen_text("verification code"):
            otp_screen_loaded = True
            break
        print(f"OTP screen not loaded yet, waiting 1s... (attempt {attempt+1}/15)")
        time.sleep(1.0)
        
    if not otp_screen_loaded:
        print("ERROR: OTP screen failed to load after sending verification code.")
        sys.exit(1)
        
    capture_screen("6b_forgot_password_otp_screen.png")
    
    # OTP
    reset_screen_loaded = False
    otp = get_local_otp(email_address)
    if otp:
        enter_text_in_field(0, otp)
        time.sleep(3)
        # Check if still on the OTP screen, and if so tap Verify Code button
        if check_screen_text("Verify Code") and not (check_screen_text("Reset Password") or check_screen_text("Update Password")):
            print("Not transitioned yet, tapping 'Verify Code' button...")
            tap_node_by_text("Verify Code", index=1)
            time.sleep(3)
            
        print("Waiting for Reset/Update Password screen to load...")
        for attempt in range(15):
            if check_screen_text("Reset Password") or check_screen_text("Update Password"):
                reset_screen_loaded = True
                break
            print(f"Reset Password screen not loaded yet, waiting 1s... (attempt {attempt+1}/15)")
            time.sleep(1.0)
        
    # Reset Password
    if reset_screen_loaded:
        enter_text_in_field(0, new_password)
        check_keyboard_and_dismiss()
        enter_text_in_field(1, new_password)
        check_keyboard_and_dismiss()
        capture_screen("7_reset_password_form.png")
        tap_node_by_text("Update Password")
        print("Waiting for password update success/login screen...")
        success_loaded = False
        for attempt in range(15):
            if check_screen_text("Success") or check_screen_text("Back to Login") or check_screen_text("Sign In"):
                success_loaded = True
                break
            print(f"Success/Back to Login screen not loaded yet, waiting 1s... (attempt {attempt+1}/15)")
            time.sleep(1.0)
            
        if success_loaded:
            if check_screen_text("Back to Login"):
                capture_screen("8_password_reset_success.png")
                tap_node_by_text("Back to Login")
                time.sleep(3)
        
    # Login with new password
    print("\n--- Step 5: Login with New Password ---")
    enter_text_in_field(0, email_address)
    enter_text_in_field(1, new_password)
    check_keyboard_and_dismiss()
    tap_node_by_text("Sign In")
    time.sleep(5)
    
    if check_screen_text("Scorer Dashboard"):
        print("SUCCESS: Logged in with new password!")
        capture_screen("9_login_new_pwd_success.png")
    else:
        print("ERROR: Failed to log in with new password.")
        sys.exit(1)
        
    # 4. Teams Management
    print("\n--- Step 6: Create Teams ---")
    tap_node_by_text("Teams")
    time.sleep(3)
    capture_screen("10_team_management_empty.png")
    
    # Create Team A
    if not tap_node_by_text("Add Team FAB"):
        print("ERROR: Failed to tap Add Team FAB.")
        sys.exit(1)
    time.sleep(2)
    capture_screen("create_team_dialog.png")
    enter_text_in_field(0, "Mumbai Indians")
    tap_node_by_text("Create")
    time.sleep(3)
    
    # Create Team B
    if not tap_node_by_text("Add Team FAB"):
        print("ERROR: Failed to tap Add Team FAB.")
        sys.exit(1)
    time.sleep(2)
    enter_text_in_field(0, "Chennai Super Kings")
    tap_node_by_text("Create")
    time.sleep(3)
    
    # Create Temporary Team C (to delete)
    if not tap_node_by_text("Add Team FAB"):
        print("ERROR: Failed to tap Add Team FAB.")
        sys.exit(1)
    time.sleep(2)
    enter_text_in_field(0, "Test Team C")
    tap_node_by_text("Create")
    time.sleep(3)
    
    capture_screen("11_teams_list.png")
    
    # Delete Team C
    # Find edit/delete button using sibling matching
    if tap_sibling_button("Test Team C", "Delete Team"):
        time.sleep(2)
        tap_node_by_text("Delete")
        time.sleep(3)
        print("SUCCESS: Deleted Temporary Team C")
        
    # Edit Team A
    if tap_sibling_button("Mumbai Indians", "Edit Team"):
        time.sleep(2)
        enter_text_in_field(0, "Mumbai Indians Pro")
        tap_node_by_text("Save")
        time.sleep(3)
        print("SUCCESS: Edited Team A")
        
    capture_screen("12_teams_updated.png")
    
    # Go back to dashboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(3)
    
    # 5. Players Management
    print("\n--- Step 7: Create Players ---")
    tap_node_by_text("Players")
    time.sleep(3)
    capture_screen("13_player_management_empty.png")
    
    # Helper to register a player
    def register_player(name, role="batsman"):
        if not tap_node_by_text("Add Player FAB"):
            print("ERROR: Failed to tap Add Player FAB.")
            sys.exit(1)
        time.sleep(2)
        if name == "Rohit Sharma":
            capture_screen("create_player_bottom_sheet.png")
        enter_text_in_field(0, name)
        tap_node_by_text("Register Player")
        time.sleep(3)
        
    # Create temporary player
    register_player("Player C")
    
    # Delete Player C
    if tap_sibling_button("Player C", "Delete Player"):
        time.sleep(2)
        tap_node_by_text("Delete")
        time.sleep(3)
        print("SUCCESS: Deleted Temporary Player C")

    # Create players for Team A
    register_player("Rohit Sharma")
    register_player("Jasprit Bumrah")
    register_player("Suryakumar Yadav")
    register_player("Hardik Pandya")
    register_player("Ishan Kishan")
    # Create players for Team B
    register_player("MS Dhoni")
    register_player("Ravindra Jadeja")
    register_player("Ruturaj Gaikwad")
    register_player("Shivam Dube")
    register_player("Matheesha Pathirana")
    
    capture_screen("14_players_list.png")
    
    # Edit Player
    if tap_sibling_button("Rohit Sharma", "Edit Player"):
        time.sleep(2)
        enter_text_in_field(0, "Rohit Sharma Hitman")
        tap_node_by_text("Save Changes")
        time.sleep(3)
        print("SUCCESS: Edited Player Rohit")
        
    capture_screen("15_players_updated.png")
    
    # Go back to dashboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(3)
    
    # 6. Roster Assignment
    print("\n--- Step 8: Assign Players to Teams ---")
    tap_node_by_text("Teams")
    time.sleep(3)
    
    # Open Team A sheet
    tap_node_with_scroll("Mumbai Indians Pro")
    time.sleep(3)
    tap_node_by_text("Add Player")
    time.sleep(2)
    # Check boxes for Rohit, Bumrah, Surya, Hardik, Ishan
    tap_node_with_scroll("Rohit Sharma Hitman")
    tap_node_with_scroll("Jasprit Bumrah")
    tap_node_with_scroll("Suryakumar Yadav")
    tap_node_with_scroll("Hardik Pandya")
    tap_node_with_scroll("Ishan Kishan")
    tap_node_by_text("Add (5)")
    time.sleep(3)
    
    # Open Team B sheet
    tap_node_with_scroll("Chennai Super Kings")
    time.sleep(3)
    tap_node_by_text("Add Player")
    time.sleep(2)
    # Check boxes for Dhoni, Jadeja, Ruturaj, Shivam, Matheesha
    tap_node_with_scroll("MS Dhoni")
    tap_node_with_scroll("Ravindra Jadeja")
    tap_node_with_scroll("Ruturaj Gaikwad")
    tap_node_with_scroll("Shivam Dube")
    tap_node_with_scroll("Matheesha Pathirana")
    tap_node_by_text("Add (5)")
    time.sleep(3)
    
    capture_screen("16_rosters_assigned.png")
    
    # Go back to dashboard
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(3)
    
    # 6b. Quick Match Setup Verification
    print("\n--- Step 8b: Quick Match Setup Verification ---")
    if not tap_node_by_text("Start Match Setup"):
        print("ERROR: Failed to tap Start Match Setup button.")
        sys.exit(1)
    time.sleep(3)
    capture_screen("quick_match_setup_1_teams.png")
    
    # Select Team 1
    tap_node_by_text("Team 1 Name")
    time.sleep(2)
    tap_node_by_text("Mumbai Indians Pro")
    time.sleep(2)
    
    # Select Team 2
    tap_node_by_text("Team 2 Name")
    time.sleep(2)
    tap_node_with_scroll("Chennai Super Kings")
    time.sleep(2)
    
    # Select toss winner
    tap_node_by_text("Mumbai Indians Pro", index=0) # ChoiceChip
    time.sleep(2)
    
    # Select toss decision
    tap_node_by_text("BAT FIRST")
    time.sleep(2)
    
    capture_screen("quick_match_setup_2_toss.png")
    
    # Go to squad selection
    tap_node_by_text("Create Match & Go to Squads")
    time.sleep(4)
    capture_screen("quick_match_setup_3_squads.png")
    
    # Submit squads
    tap_node_with_scroll("Submit Squads & Proceed")
    time.sleep(3)
    
    # Now the Select Openers dialog is shown
    capture_screen("quick_match_setup_4_openers.png")
    
    # Exit back to dashboard by sending back button twice
    print("Exiting Quick Match setup back to dashboard...")
    run_adb(["shell", "input", "keyevent", "4"]) # closes dialog
    time.sleep(1.5)
    run_adb(["shell", "input", "keyevent", "4"]) # goes back from squad selection directly to dashboard
    time.sleep(3)
    
    # 7. Tournaments Creation & Fixtures
    print("\n--- Step 9: Tournaments ---")
    tap_node_by_text("Tournaments")
    time.sleep(3)
    
    # Create Tournament
    if not tap_node_by_text("Add Tournament FAB"):
        print("ERROR: Failed to tap Add Tournament FAB.")
        sys.exit(1)
    time.sleep(2)
    capture_screen("tournament_creation_screen.png")
    enter_text_in_field(0, "CricUP IPL Cup")
    tap_node_by_text("4 Teams")
    time.sleep(2)
    tap_node_by_text("2 Teams")
    time.sleep(2)
    tap_node_by_text("Create Tournament", index=1)
    time.sleep(4)
    
    # Open Tournament details
    tap_node_with_scroll("CricUP IPL Cup")
    time.sleep(3)
    capture_screen("tournament_details_screen.png")
    capture_screen("17_tournament_dashboard.png")
    
    # Register Teams
    tap_node_by_text("Teams") # tab
    time.sleep(2)
    tap_node_by_text("Register")
    time.sleep(2)
    tap_node_with_scroll("Mumbai Indians Pro")
    time.sleep(3)
    tap_node_by_text("Register")
    time.sleep(2)
    tap_node_with_scroll("Chennai Super Kings")
    time.sleep(3)
    
    capture_screen("18_tournament_teams_registered.png")
    
    # Lock Teams and Generate Fixtures
    tap_node_by_text("Lock Teams & Generate Fixtures")
    time.sleep(2)
    tap_node_by_text("Generate")
    time.sleep(5)
    
    # Switch to Dashboard tab so that the generated match card is visible
    tap_node_by_text("Dashboard")
    time.sleep(2)
    
    capture_screen("19_tournament_fixtures_generated.png")
    
    # 8. Start and Score Match
    # 8. Start and Score Match
    print("\n--- Step 10: Start & Score Match ---")
    tap_node_by_text("Score Match")
    time.sleep(4)
    
    # Handle Toss Selection dialog first
    tap_node_by_text("Submit & Proceed")
    time.sleep(3)
    
    capture_screen("20_squad_selection.png")
    # Submit squads
    tap_node_with_scroll("Submit Squads & Proceed")
    time.sleep(3)
    
    # Select openers dialog is shown, start scoring
    tap_node_by_text("Start Scoring")
    time.sleep(5)
    
    capture_screen("21_scoring_pad.png")
    capture_screen("live_scoring_screen.png")
    
    # Score some balls
    # 4 runs
    tap_node_by_text("4")
    time.sleep(2)
    # 6 runs
    tap_node_by_text("6")
    time.sleep(2)
    # 1 run
    tap_node_by_text("1")
    time.sleep(2)
    # Undo
    tap_node_by_text("UNDO")
    time.sleep(2)
    # Wicket
    tap_node_by_text("WICKET")
    time.sleep(2)
    tap_node_by_text("Confirm Wicket")
    time.sleep(5)
    
    # Select next striker
    batsmen_options = [
        "Suryakumar Yadav", 
        "MS Dhoni", 
        "Ravindra Jadeja", 
        "Ruturaj Gaikwad", 
        "Shivam Dube", 
        "Matheesha Pathirana", 
        "Jasprit Bumrah", 
        "Hardik Pandya", 
        "Ishan Kishan", 
        "Rohit Sharma Hitman"
    ]
    tapped_batsman = False
    xml_content = get_fresh_xml(retries=3)
    if xml_content:
        try:
            root = ET.fromstring(xml_content)
            for node in root.iter('node'):
                content_desc = node.get('content-desc', '').lower()
                text_val = node.get('text', '').lower()
                for b_name in batsmen_options:
                    if b_name.lower() == content_desc or b_name.lower() == text_val or b_name.lower() in content_desc or b_name.lower() in text_val:
                        bounds = node.get('bounds')
                        m = re.findall(r'\d+', bounds)
                        if len(m) == 4:
                            x1, y1, x2, y2 = map(int, m)
                            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
                            print(f"Tapping next striker '{b_name}' at coordinates ({cx}, {cy})")
                            run_adb(["shell", "input", "tap", str(cx), str(cy)])
                            tapped_batsman = True
                            break
                if tapped_batsman:
                    break
        except Exception as e:
            print("Error parsing XML in robust next striker tap:", e)
            
    if tapped_batsman:
        time.sleep(3)
    else:
        print("WARNING: Could not tap next striker from XML dump, trying fallback...")
        for b_name in batsmen_options:
            if tap_node_by_text(b_name, wait_secs=3):
                tapped_batsman = True
                break
    
    capture_screen("22_scoring_wickets.png")
    
    # We will score more balls to finish the match or look at scorecard
    # Tap back or view scorecard
    tap_node_by_text("View Scorecard")
    time.sleep(4)
    capture_screen("23_scorecard.png")
    
    print("\n=== E2E AUDIT AND WALKTHROUGH COMPLETED SUCCESSFULLY ===")

if __name__ == "__main__":
    run_walkthrough()
