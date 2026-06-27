import subprocess
import time
import os
import sys
import xml.etree.ElementTree as ET
import re
import psycopg2
from psycopg2.extras import RealDictCursor
import uuid
import datetime

# Database setup
prod_db_url = 'postgresql://postgres:FRyHJtedUQRkifiAdJLUhuhqwOvEFtdf@thomas.proxy.rlwy.net:35136/railway'

def run_sql(query, params=None, fetch=False):
    conn = psycopg2.connect(prod_db_url)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            if fetch:
                return cur.fetchall()
            conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

def prepare_production_db():
    print("Preparing production database users and cleaning up test data via raw SQL...")
    hashed_pwd = "$2b$12$zbvk0gLq4hjgUGaBBRcfnu49IqXLtUKPoto4OLVHKPeE2zcqaaiDm"  # Password123
    
    def upsert_user(email, username, display_name, role):
        existing = run_sql("SELECT id FROM users WHERE email = %s", (email,), fetch=True)
        if existing:
            uid = existing[0]['id']
            run_sql("""
                UPDATE users SET
                    username = %s,
                    hashed_password = %s,
                    email_verified = true,
                    is_active = true,
                    is_deleted = false,
                    profile_completed = true,
                    display_name = %s,
                    full_name = %s,
                    role = %s
                WHERE id = %s
            """, (username, hashed_pwd, display_name, display_name, role, uid))
            print(f"Updated test user {email} (ID: {uid})")
            return uid
        else:
            uid = str(uuid.uuid4())
            run_sql("""
                INSERT INTO users (id, email, username, hashed_password, email_verified, is_active, is_deleted, profile_completed, display_name, full_name, role)
                VALUES (%s, %s, %s, %s, true, true, false, true, %s, %s, %s)
            """, (uid, email, username, hashed_pwd, display_name, display_name, role))
            print(f"Created test user {email} (ID: {uid})")
            return uid
            
    cap_id = upsert_user("captain@cricup.com", "captain_user", "Captain User", "player")
    play_id = upsert_user("player@cricup.com", "player_user", "Player User", "player")
    test_id = upsert_user("testuser@cricup.com", "testuser", "Test User", "scorer")
    
    # Clean up test teams and members
    teams = run_sql("SELECT id FROM teams WHERE name IN (%s, %s, %s) OR created_by = %s", ("Notification Team", "Notif Team Redux", "Auto Team Verified", cap_id), fetch=True)
    team_ids = [t['id'] for t in teams]
    
    if team_ids:
        for tid in team_ids:
            run_sql("DELETE FROM team_members WHERE team_id = %s", (tid,))
            run_sql("DELETE FROM team_players WHERE team_id = %s", (tid,))
            run_sql("DELETE FROM matches WHERE team1_id = %s OR team2_id = %s", (tid, tid))
            run_sql("DELETE FROM teams WHERE id = %s", (tid,))
            
    # Delete notifications
    run_sql("DELETE FROM notifications WHERE user_id IN (%s, %s, %s)", (cap_id, play_id, test_id))
    print("Database preparation and clean completed successfully.")

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

# Artifacts output directory
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\905bb39b-da58-4fe6-b469-d9e9c2e5e67b"

def run_adb(args, timeout=60.0):
    cmd = [ADB, "-s", DEVICE] + args
    try:
        res = subprocess.run(cmd, capture_output=True, timeout=timeout)
        return res.stdout.decode('utf-8', errors='ignore')
    except subprocess.TimeoutExpired:
        print(f"WARNING: ADB command timed out after {timeout}s: {' '.join(cmd)}")
        return ""

def capture_screenshot(name):
    run_adb(["shell", "screencap", "-p", f"/data/local/tmp/{name}.png"])
    local_path = os.path.join(ARTIFACTS_DIR, f"{name}.png")
    run_adb(["pull", f"/data/local/tmp/{name}.png", local_path])
    print(f"Captured screenshot: {local_path}")
    return local_path

def ensure_app_foreground():
    focused = run_adb(["shell", "dumpsys window | grep mCurrentFocus"])
    if "com.cricup" not in focused:
        print("CricUp is not in focus. Bringing it to the foreground...")
        run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
        time.sleep(4.0)

def get_fresh_xml(retries=5):
    for attempt in range(retries):
        time.sleep(1.0)
        run_adb(["shell", "rm", "-f", "/data/local/tmp/window_dump.xml"])
        dump_res = run_adb(["shell", "uiautomator", "dump", "/data/local/tmp/window_dump.xml"])
        if "dumped to" in dump_res or "UI hierchary" in dump_res:
            xml_content = run_adb(["shell", "cat", "/data/local/tmp/window_dump.xml"])
            if xml_content.strip() and "hierarchy" in xml_content:
                try:
                    ET.fromstring(xml_content)
                    return xml_content
                except Exception:
                    pass
        print(f"UI Automator dump failed on attempt {attempt+1}/{retries}. Running recovery...")
        ensure_app_foreground()
        if attempt == 2:
            print("UI Automator might be stuck or covered. Pressing back to clear system overlay/dialogs...")
            run_adb(["shell", "input", "keyevent", "4"])
            time.sleep(1.0)
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
                content_desc = node.get('content-desc', '').strip().lower()
                text_val = node.get('text', '').strip().lower()
                clean_query = text_query.strip().lower()
                if clean_query == content_desc or clean_query == text_val:
                    nodes.append(node)
            if not nodes and not exact:
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

def tap_node_by_text(text, index=0, wait_secs=3, exact=False):
    coords = get_node_center_by_text(text, index, exact=exact)
    if coords:
        time.sleep(1.0)
        print(f"Tapping '{text}' (exact={exact}) at coordinates {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        time.sleep(wait_secs)
        return True
    print(f"WARNING: Could not find node with text '{text}' (exact={exact})")
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
        if y > 1800:
            print(f"Item is near bottom (y={y}). Swiping up to clear the FAB...")
            run_adb(["shell", "input", "swipe", "500", "1500", "500", "1000", "300"])
            time.sleep(1.5)
            coords = get_node_center_by_text(team_name, exact=False)
            if not coords:
                print("ERROR: Lost team card coordinates after extra swipe.")
                return False
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
    out = run_adb(["shell", "dumpsys input_method | grep mInputShown"])
    return "mInputShown=true" in out

def dismiss_keyboard():
    if is_keyboard_shown():
        print("Keyboard is shown. Dismissing...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.0)
    else:
        print("Keyboard is already dismissed.")

def enter_text_in_field(field_index, text_val):
    field = get_node_center_by_class("android.widget.EditText", field_index)
    if field:
        print(f"EditText index {field_index} found at center {field}. Tapping to focus...")
        run_adb(["shell", "input", "tap", str(field[0]), str(field[1])])
        time.sleep(1.0)
        
        print("Clearing field...")
        for _ in range(25):
            run_adb(["shell", "input", "keyevent", "67"])
        time.sleep(0.5)
        
        print(f"Typing value into field {field_index}...")
        escaped_val = text_val.replace(" ", "%s").replace("!", "\\!")
        run_adb(["shell", "input", "text", escaped_val])
        time.sleep(1.0)
        
        dismiss_keyboard()
        return True
    print(f"WARNING: Could not find EditText at index {field_index}")
    return False

def get_appbar_button_coords(button_type):
    # button_type can be 'notifications' or 'logout'
    xml_content = get_fresh_xml(retries=3)
    if not xml_content:
        return None
    try:
        root = ET.fromstring(xml_content)
        buttons = []
        for node in root.iter("node"):
            if node.get("class") == "android.widget.Button" or node.get("class") == "android.widget.ImageView":
                bounds = node.get("bounds")
                m = re.findall(r"\d+", bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
                    if cy < 280:
                        desc = node.get("content-desc", "").lower()
                        buttons.append((cx, cy, desc))
        
        # Deduplicate buttons near the same x, y coordinates
        unique_buttons = []
        for b in buttons:
            if any(abs(b[0] - ub[0]) < 20 and abs(b[1] - ub[1]) < 20 for ub in unique_buttons):
                continue
            unique_buttons.append(b)
            
        unique_buttons.sort(key=lambda x: x[0])
        print(f"Detected appbar buttons (sorted by x): {unique_buttons}")
        
        # Filter out navigation/back buttons on the left (cx < 200)
        actions_buttons = [ub for ub in unique_buttons if ub[0] > 200]
        
        if button_type == 'notifications':
            if actions_buttons:
                return actions_buttons[0][0], actions_buttons[0][1]
        elif button_type == 'logout':
            for ub in unique_buttons:
                if 'logout' in ub[2]:
                    return ub[0], ub[1]
            if actions_buttons:
                return actions_buttons[-1][0], actions_buttons[-1][1]
    except Exception as e:
        print(f"Error parsing appbar buttons: {e}")
    return None

def login(email, password):
    print(f"Logging in as {email}...")
    
    # Wait for login screen to load
    for attempt in range(5):
        if check_screen_text("welcome back") or check_screen_text("continue with google") or check_screen_text("Sign In"):
            break
        time.sleep(1.5)
        
    if not enter_text_in_field(0, email):
        raise Exception("Failed to enter email.")
    if not enter_text_in_field(1, password):
        raise Exception("Failed to enter password.")
    dismiss_keyboard()
    if not tap_node_by_text("Sign In", exact=True):
        print("Sign In node not found by text, using coordinates...")
        run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(6.0)

    logged_in = False
    for attempt in range(5):
        if check_screen_text("scorer dashboard") or check_screen_text("dashboard") or check_screen_text("admin dashboard"):
            logged_in = True
            break
        time.sleep(1.5)
    if not logged_in:
        raise Exception(f"Login failed for {email}.")
    print("Login successful!")

def logout():
    print("Logging out...")
    coords = get_appbar_button_coords('logout')
    if coords:
        print(f"Tapping logout button at center {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
    else:
        print("WARNING: Logout button not detected, using fallback coordinate (1014, 160)...")
        run_adb(["shell", "input", "tap", "1014", "160"])
    time.sleep(4.0)

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
    for attempt in range(6):
        if check_screen_text("Teams") and check_screen_text("Matches"):
            print("Successfully reached dashboard screen!")
            return True
        if check_screen_text("welcome back") or check_screen_text("continue with google") or check_screen_text("Sign In"):
            print("Kicked back to login screen.")
            return False
            
        print(f"Not on dashboard yet. Pressing keyevent 4... (attempt {attempt+1})")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(2.5)
        
    raise Exception("Failed to return to dashboard after multiple attempts.")

def open_notifications_screen():
    print("Opening Notifications screen...")
    for attempt in range(3):
        coords = get_appbar_button_coords('notifications')
        if coords:
            print(f"Tapping notifications icon at center {coords}")
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        else:
            print("WARNING: Notifications icon not detected, using fallback (750, 160)...")
            run_adb(["shell", "input", "tap", "750", "160"])
            
        time.sleep(3.0)
        if check_screen_text("Notifications", retries=2):
            print("Successfully opened Notifications screen!")
            return True
        print(f"Notifications screen not open yet. Retrying tap... (attempt {attempt+1})")
    raise Exception("Failed to open Notifications screen")

def main():
    prepare_production_db()
    
    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    
    print("Clearing app data to ensure fresh environment...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)
    
    print("Launching app...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(6.0)
    
    # Bypass onboarding
    if check_screen_text("Skip"):
        print("Bypassing onboarding...")
        tap_node_by_text("Skip")
        time.sleep(4.0)

    # 1. Log in as Captain
    login("captain@cricup.com", "Password123")
    
    # Create Team
    print("Creating Notification Team...")
    tap_node_by_text("Teams")
    time.sleep(2.0)
    
    # Tap Create Team FAB
    tap_node_by_text("Add Team FAB")
    time.sleep(2.5)
    
    enter_text_in_field(0, "Notification Team")
    enter_text_in_field(1, "Testing notification center compliance E2E.")
    # Tap Create button
    tap_node_by_text("Create", exact=True)
    time.sleep(4.0)
    
    # Tap Notification Team from active list
    tap_node_by_text("Notification Team")
    time.sleep(3.0)
    
    # Go to members tab
    tap_node_by_text("Members")
    time.sleep(2.0)
    
    # Invite testuser@cricup.com first (to test revocation)
    print("Inviting testuser@cricup.com...")
    tap_node_by_text("Add Member")
    time.sleep(2.0)
    enter_text_in_field(0, "testuser@cricup.com")
    tap_node_by_text("Add", exact=True)
    time.sleep(3.0)
    
    # Revoke it
    print("Revoking invitation...")
    tap_node_by_text("Revoke")
    time.sleep(3.0)
    
    # Invite player@cricup.com
    print("Inviting player@cricup.com...")
    tap_node_by_text("Add Member")
    time.sleep(2.0)
    enter_text_in_field(0, "player@cricup.com")
    tap_node_by_text("Add", exact=True)
    time.sleep(3.0)
    
    capture_screenshot("notif_captain_invited_player")
    
    go_back_to_dashboard()
    logout()
    
    # 2. Log in as Player to DECLINE invitation
    login("player@cricup.com", "Password123")
    
    # Verify unread count badge
    capture_screenshot("notif_player_unread_badge")
    
    # Open Notifications
    open_notifications_screen()
    capture_screenshot("notif_player_notifications_list")
    
    # Filter by category Team
    tap_node_by_text("Team", exact=True)
    time.sleep(2.0)
    capture_screenshot("notif_player_filtered_team")
    
    # Tap Decline
    print("Declining invitation directly from card...")
    tap_node_by_text("Decline", exact=True)
    time.sleep(3.0)
    capture_screenshot("notif_player_invitation_declined")
    
    go_back_to_dashboard()
    logout()
    
    # 3. Log in as Captain to see Invitation Rejected
    login("captain@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_captain_invitation_rejected")
    
    # Go back to Dashboard, Teams -> Notification Team -> Members -> Invite Player again
    go_back_to_dashboard()
    tap_node_by_text("Teams")
    time.sleep(2.0)
    tap_node_by_text("Notification Team")
    time.sleep(2.0)
    tap_node_by_text("Members")
    time.sleep(2.0)
    tap_node_by_text("Add Member")
    time.sleep(2.0)
    enter_text_in_field(0, "player@cricup.com")
    tap_node_by_text("Add", exact=True)
    time.sleep(3.0)
    
    go_back_to_dashboard()
    logout()
    
    # 4. Log in as Player to ACCEPT invitation
    login("player@cricup.com", "Password123")
    open_notifications_screen()
    tap_node_by_text("Team", exact=True)
    time.sleep(1.5)
    print("Accepting invitation directly from card...")
    tap_node_by_text("Accept", exact=True)
    time.sleep(3.0)
    capture_screenshot("notif_player_invitation_accepted")
    
    go_back_to_dashboard()
    logout()
    
    # 5. Log in as Captain to see Accept notification & Promote/Demote/Transfer roles
    login("captain@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_captain_invitation_accepted_notif")
    
    go_back_to_dashboard()
    tap_node_by_text("Teams")
    time.sleep(2.0)
    tap_node_by_text("Notification Team")
    time.sleep(2.0)
    tap_node_by_text("Members")
    time.sleep(2.0)
    
    # Tap PopupMenu next to Player User (which is the only active member who is not Captain)
    print("Tapping member management popup menu...")
    tap_node_by_text("Show menu", index=1)
    time.sleep(2.0)
    capture_screenshot("notif_captain_member_menu")
    
    # Promote to Vice Captain
    print("Promoting player to Vice Captain...")
    tap_node_by_text("Assign Vice Captain")
    time.sleep(3.0)
    capture_screenshot("notif_captain_promoted_vc")
    
    # Tapping popup menu again
    print("Tapping member management popup menu...")
    tap_node_by_text("Show menu", index=1)
    time.sleep(2.0)
    
    # Demote Vice Captain
    print("Demoting Vice Captain back to player...")
    tap_node_by_text("Remove Vice Captain")
    time.sleep(3.0)
    capture_screenshot("notif_captain_demoted_vc")
    
    # Tapping popup menu again to transfer Captaincy
    print("Tapping member management popup menu...")
    tap_node_by_text("Show menu", index=1)
    time.sleep(2.0)
    
    print("Transferring captaincy (Making Captain)...")
    tap_node_by_text("Make Captain")
    time.sleep(2.0)
    tap_node_by_text("Confirm", exact=True)
    time.sleep(4.0)
    capture_screenshot("notif_captaincy_transferred")
    
    go_back_to_dashboard()
    logout()
    
    # 6. Log in as Player (now Captain) to verify role change & remove member
    login("player@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_player_captain_changed")
    
    go_back_to_dashboard()
    tap_node_by_text("Teams")
    time.sleep(2.0)
    tap_node_by_text("Notification Team")
    time.sleep(2.0)
    tap_node_by_text("Members")
    time.sleep(2.0)
    
    # Remove previous Captain (Captain User)
    print("Removing previous captain from team...")
    tap_node_by_text("Show menu", index=1)
    time.sleep(2.0)
    tap_node_by_text("Remove Member")
    time.sleep(2.0)
    tap_node_by_text("Remove", exact=True)
    time.sleep(4.0)
    capture_screenshot("notif_player_removed_previous_captain")
    
    go_back_to_dashboard()
    logout()
    
    # 7. Log in as Captain to see removal and request to join (triggers join_request_sent)
    login("captain@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_captain_removed_member")
    
    go_back_to_dashboard()
    tap_node_by_text("Teams")
    time.sleep(2.0)
    tap_node_by_text("Explore Teams")
    time.sleep(2.0)
    enter_text_in_field(0, "Notification")
    time.sleep(2.0)
    
    print("Tapping Join on Explore Teams list...")
    tap_join_for_team("Notification Team")
    time.sleep(4.0)
    capture_screenshot("notif_captain_join_request_sent")
    
    logout()
    
    # 8. Log in as Player to Reject Join Request directly
    login("player@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_player_join_request_card")
    
    print("Rejecting join request directly from notification...")
    tap_node_by_text("Reject", exact=True)
    time.sleep(3.0)
    capture_screenshot("notif_player_join_request_rejected")
    
    logout()
    
    # 9. Log in as Captain to see Join Request Rejected and request to join again
    login("captain@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_captain_request_rejected_notif")
    
    go_back_to_dashboard()
    tap_node_by_text("Teams")
    time.sleep(2.0)
    tap_node_by_text("Explore Teams")
    time.sleep(2.0)
    enter_text_in_field(0, "Notification Team")
    time.sleep(2.0)
    tap_join_for_team("Notification Team")
    time.sleep(4.0)
    
    logout()
    
    # 10. Log in as Player to Approve Join Request directly
    login("player@cricup.com", "Password123")
    open_notifications_screen()
    print("Approving join request directly from notification...")
    tap_node_by_text("Approve", exact=True)
    time.sleep(3.0)
    capture_screenshot("notif_player_join_request_approved")
    
    logout()
    
    # 11. Log in as Captain to see Approved and Leave the team
    login("captain@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_captain_request_approved_notif")
    
    # Tap the notification card to DEEP LINK directly to TeamDetailsScreen!
    print("Tapping Join Request Approved notification to deep link...")
    tap_node_by_text("Join Request Approved")
    time.sleep(4.0)
    capture_screenshot("notif_captain_deep_linked_team_details")
    
    # Leave the team (Tapping menu button index 0 on app bar)
    print("Tapping team detail settings menu...")
    tap_node_by_text("Show menu", index=0)
    time.sleep(2.0)
    tap_node_by_text("Leave Team")
    time.sleep(2.0)
    tap_node_by_text("Leave", exact=True)
    time.sleep(4.0)
    
    logout()
    
    # 12. Log in as Player to see Member Left and delete team
    login("player@cricup.com", "Password123")
    open_notifications_screen()
    capture_screenshot("notif_player_member_left")
    
    # Go to Teams -> Notification Team -> Edit (triggers team_updated) -> Delete (triggers team_deleted)
    go_back_to_dashboard()
    tap_node_by_text("Teams")
    time.sleep(2.0)
    tap_node_by_text("Notification Team")
    time.sleep(2.0)
    
    # Edit details
    tap_node_by_text("Show menu", index=0)
    time.sleep(2.0)
    tap_node_by_text("Edit Team")
    time.sleep(2.0)
    enter_text_in_field(0, "Notif Team Redux")
    tap_node_by_text("SAVE CHANGES", exact=True)
    time.sleep(4.0)
    
    # Delete details
    tap_node_by_text("Show menu", index=0)
    time.sleep(2.0)
    tap_node_by_text("Delete Team")
    time.sleep(2.0)
    tap_node_by_text("Delete", exact=True)
    time.sleep(4.0)
    capture_screenshot("notif_player_team_deleted_success")
    
    logout()
    print("\nALL IN-APP NOTIFICATION COMPLIANCE AUTOMATED FLOWS COMPLETED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
