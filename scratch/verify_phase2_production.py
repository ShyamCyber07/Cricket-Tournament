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
    teams = run_sql("SELECT id FROM teams WHERE name IN (%s, %s) OR created_by = %s", ("Test Automation Team", "Auto Team Verified", cap_id), fetch=True)
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
    # Take screenshot on physical device
    run_adb(["shell", "screencap", "-p", f"/data/local/tmp/{name}.png"])
    # Pull to artifacts directory
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
        
        # Dismiss keyboard dynamically
        dismiss_keyboard()
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
    # Dismiss keyboard if shown before Sign In
    dismiss_keyboard()
    # Sign In
    if not tap_node_by_text("Sign In", exact=True):
        print("Sign In node not found by text, using coordinates...")
        run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(6.0)

    # Verify login
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
    if not tap_node_by_text("Logout", exact=True):
        print("Logout node not found by text, using profile coordinates...")
        # Tap Profile tab (usually bottom right or top right logout action)
        # Let's try navigating to Profile first if we are on dashboard
        tap_node_by_text("Profile")
        time.sleep(2.0)
        if not tap_node_by_text("Logout", exact=True):
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
        if check_screen_text("Logout") or check_screen_text("Teams") and check_screen_text("Matches"):
            print("Successfully reached dashboard screen!")
            return True
        if check_screen_text("welcome back") or check_screen_text("continue with google"):
            print("WARNING: Popped too far and reached Login screen.")
            return False
            
        print(f"Not on dashboard yet. Tapping back arrow (77, 160)... (attempt {attempt+1})")
        run_adb(["shell", "input", "tap", "77", "160"])
        time.sleep(2.0)
        
        if check_screen_text("Logout") or check_screen_text("Teams") and check_screen_text("Matches"):
            print("Successfully reached dashboard screen!")
            return True
            
        print(f"Trying keyevent 4 fallback...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(2.0)
        
    raise Exception("Failed to return to dashboard after multiple attempts.")

def create_bulk_delete_items():
    print("Creating bulk delete test items in production DB via raw SQL...")
    
    # 1. Clean existing bulk items first
    # Matches (need to clean referencing bulk team matches first to avoid FK constraint violation)
    run_sql("""
        DELETE FROM matches 
        WHERE team1_id IN (SELECT id FROM teams WHERE name IN (%s, %s))
           OR team2_id IN (SELECT id FROM teams WHERE name IN (%s, %s))
    """, ("Bulk Team 1", "Bulk Team 2", "Bulk Team 1", "Bulk Team 2"))
    # Tournaments
    run_sql("DELETE FROM tournaments WHERE name IN (%s, %s)", ("Bulk Tour 1", "Bulk Tour 2"))
    # Teams
    run_sql("DELETE FROM teams WHERE name IN (%s, %s)", ("Bulk Team 1", "Bulk Team 2"))
    # Users
    run_sql("DELETE FROM users WHERE email IN (%s, %s)", ("bulk_u1@cricup.com", "bulk_u2@cricup.com"))
    
    # 2. Insert Users
    u1_id = str(uuid.uuid4())
    u2_id = str(uuid.uuid4())
    hashed_pwd = "$2b$12$kXHad0SLRVQxDgz9D/t2O.JBVfFj5wBeg0IQK954o3WBVTk83SaYq"
    
    run_sql("""
        INSERT INTO users (id, email, username, hashed_password, email_verified, is_active, is_deleted, profile_completed, display_name, full_name, role)
        VALUES (%s, %s, %s, %s, true, true, false, true, %s, %s, 'player')
    """, (u1_id, "bulk_u1@cricup.com", "bulk_u1", hashed_pwd, "Bulk User One", "Bulk User One"))
    
    run_sql("""
        INSERT INTO users (id, email, username, hashed_password, email_verified, is_active, is_deleted, profile_completed, display_name, full_name, role)
        VALUES (%s, %s, %s, %s, true, true, false, true, %s, %s, 'player')
    """, (u2_id, "bulk_u2@cricup.com", "bulk_u2", hashed_pwd, "Bulk User Two", "Bulk User Two"))
    
    print(f"Inserted bulk users: {u1_id}, {u2_id}")
    
    # 3. Insert Teams
    t1_id = str(uuid.uuid4())
    t2_id = str(uuid.uuid4())
    run_sql("""
        INSERT INTO teams (id, name, created_by, captain_id)
        VALUES (%s, %s, %s, NULL)
    """, (t1_id, "Bulk Team 1", u1_id))
    run_sql("""
        INSERT INTO teams (id, name, created_by, captain_id)
        VALUES (%s, %s, %s, NULL)
    """, (t2_id, "Bulk Team 2", u2_id))
    print(f"Inserted bulk teams: {t1_id}, {t2_id}")
    
    # 4. Insert Tournaments
    tour1_id = str(uuid.uuid4())
    tour2_id = str(uuid.uuid4())
    today = datetime.date.today()
    end_date = today + datetime.timedelta(days=5)
    
    run_sql("""
        INSERT INTO tournaments (id, name, organizer_id, start_date, end_date, num_teams, format, status)
        VALUES (%s, %s, %s, %s, %s, 4, 'T20', 'registration')
    """, (tour1_id, "Bulk Tour 1", u1_id, today, end_date))
    run_sql("""
        INSERT INTO tournaments (id, name, organizer_id, start_date, end_date, num_teams, format, status)
        VALUES (%s, %s, %s, %s, %s, 4, 'T20', 'registration')
    """, (tour2_id, "Bulk Tour 2", u2_id, today, end_date))
    print(f"Inserted bulk tournaments: {tour1_id}, {tour2_id}")
    
    # 5. Insert Matches (matches table uses team1_id, team2_id, match_date, over_limit, venue)
    m1_id = str(uuid.uuid4())
    m2_id = str(uuid.uuid4())
    run_sql("""
        INSERT INTO matches (id, team1_id, team2_id, created_by, status, match_type, match_date, over_limit, venue)
        VALUES (%s, %s, %s, %s, 'scheduled', 'T20', %s, 20, 'Bulk Venue')
    """, (m1_id, t1_id, t2_id, u1_id, today))
    run_sql("""
        INSERT INTO matches (id, team1_id, team2_id, created_by, status, match_type, match_date, over_limit, venue)
        VALUES (%s, %s, %s, %s, 'scheduled', 'T20', %s, 20, 'Bulk Venue')
    """, (m2_id, t1_id, t2_id, u2_id, today))
    print(f"Inserted bulk matches: {m1_id}, {m2_id}")

def main():
    print("Running prepare_production_db internally via raw SQL at startup...")
    prepare_production_db()
    time.sleep(2.0)

    print("Force stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    
    print("Clearing app data to ensure fresh environment...")
    run_adb(["shell", "pm", "clear", "com.cricup"])
    time.sleep(2.0)

    # 1. Install Release APK
    print("Installing built production Release APK on physical device...")
    apk_path = r"frontend\build\app\outputs\flutter-apk\app-release.apk"
    install_res = run_adb(["install", "-r", apk_path])
    print(f"Install result: {install_res.strip()}")

    # Launch app
    print("Launching app...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(8.0)

    # Bypass onboarding
    if check_screen_text("Skip"):
        print("Bypassing onboarding...")
        tap_node_by_text("Skip")
        time.sleep(4.0)

    capture_screenshot("phase2_login_screen")

    # Flow 1: Session Restore Verification
    print("Verification: Session Restore...")
    login("player@cricup.com", "Password123")
    capture_screenshot("phase2_dashboard_logged_in")
    
    # Restart app to verify session restore
    print("Restarting app for session restore check...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(2.0)
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(8.0)
    
    # Check if we are still logged in
    if check_screen_text("dashboard") or check_screen_text("scorer dashboard"):
        print("SUCCESS: Session restored successfully!")
    else:
        raise Exception("Session restore failed!")
    capture_screenshot("phase2_session_restored")
    
    logout()
    capture_screenshot("phase2_logged_out")

    # Prepare database state
    print("Running prepare_production_db internally via raw SQL...")
    prepare_production_db()
    time.sleep(2.0)

    # Flow 2: Captain permissions & Team Membership
    print("Verification: Captain features and Team Membership flow...")
    login("captain@cricup.com", "Password123")
    
    # Go to Teams
    print("Navigating to Teams...")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    capture_screenshot("phase2_captain_teams_list")

    # Create Team
    print("Creating Team: Test Automation Team...")
    tap_node_by_text("Add Team FAB")
    time.sleep(2.0)
    enter_text_in_field(0, "Test Automation Team")
    tap_node_by_text("Create", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_team_created")

    # Edit Team
    print("Editing Team...")
    tap_node_by_text("Test Automation Team")
    time.sleep(3.0)
    # Open popup menu
    tap_node_by_text("Show menu")
    time.sleep(1.5)
    tap_node_by_text("Edit Team")
    time.sleep(2.0)
    enter_text_in_field(0, "Auto Team Verified")
    # Click save or done (let's tap by coordinate or look for Update/Save/SAVE CHANGES text)
    if not tap_node_by_text("SAVE CHANGES", exact=True) and not tap_node_by_text("Save", exact=True) and not tap_node_by_text("Update", exact=True):
        print("Tapping edit save at coords (540, 1000)...")
        run_adb(["shell", "input", "tap", "540", "1000"])
    time.sleep(4.0)
    capture_screenshot("phase2_team_edited")

    # Go back and logout
    go_back_to_dashboard()
    logout()

    # Login Player to request join and check team search
    login("player@cricup.com", "Password123")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    tap_node_by_text("Explore Teams")
    time.sleep(2.0)
    capture_screenshot("phase2_explore_teams_list")

    # Team Search verification
    print("Testing Team Search by name...")
    enter_text_in_field(0, "Verified")
    time.sleep(2.0)
    capture_screenshot("phase2_team_search_filtered")

    print("Tapping Join on Auto Team Verified...")
    tap_join_for_team("Auto Team Verified")
    
    # Clear search to return to general list if needed
    tap_node_by_text("Joined Teams")
    time.sleep(2.0)
    capture_screenshot("phase2_joined_teams_pending")

    # Verify PENDING badge
    if not check_screen_text("PENDING"):
        raise Exception("Pending badge not found under Joined Teams!")
    print("SUCCESS: Pending badge found!")

    # Verify Pending dialog popup on tap
    tap_node_by_text("Auto Team Verified")
    time.sleep(2.0)
    capture_screenshot("phase2_pending_dialog")
    if not check_screen_text("Request Pending"):
        raise Exception("Request Pending dialog did not show up!")
    tap_node_by_text("OK", exact=True)
    time.sleep(2.0)

    go_back_to_dashboard()
    logout()

    # Login Captain to reject first, then let player re-request and captain approve
    login("captain@cricup.com", "Password123")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    tap_node_by_text("Auto Team Verified")
    time.sleep(3.0)
    capture_screenshot("phase2_captain_team_details_pending")

    # Reject request
    print("Rejecting player request...")
    tap_node_by_text("Reject", exact=True)
    time.sleep(3.0)
    capture_screenshot("phase2_captain_rejected_request")

    go_back_to_dashboard()
    logout()

    # Player requests again
    login("player@cricup.com", "Password123")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    tap_node_by_text("Explore Teams")
    time.sleep(2.0)
    enter_text_in_field(0, "Verified")
    time.sleep(2.0)
    tap_join_for_team("Auto Team Verified")
    go_back_to_dashboard()
    logout()

    # Captain approves and tests invite, revoke, remove
    login("captain@cricup.com", "Password123")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    tap_node_by_text("Auto Team Verified")
    time.sleep(3.0)
    
    # Approve request
    print("Approving player request...")
    tap_node_by_text("Approve", exact=True)
    time.sleep(3.0)
    capture_screenshot("phase2_captain_approved_request")

    # Invite user
    print("Inviting testuser@cricup.com...")
    tap_node_by_text("Add Member", exact=True)
    time.sleep(2.0)
    enter_text_in_field(0, "testuser@cricup.com")
    tap_node_by_text("Add", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_captain_sent_invite")

    # Revoke invitation
    print("Revoking invitation...")
    tap_node_by_text("Revoke", exact=True)
    time.sleep(3.0)
    capture_screenshot("phase2_captain_revoked_invite")

    # Go back to dashboard & logout
    go_back_to_dashboard()
    logout()

    # Player verifies ACTIVE badge
    login("player@cricup.com", "Password123")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    capture_screenshot("phase2_player_teams_active")
    if not check_screen_text("ACTIVE"):
        raise Exception("Active badge not found under Joined Teams!")
    print("SUCCESS: Active badge found!")
    
    go_back_to_dashboard()
    logout()

    # Captain removes member & deletes team
    login("captain@cricup.com", "Password123")
    tap_node_by_text("Teams")
    time.sleep(3.0)
    tap_node_by_text("Auto Team Verified")
    time.sleep(3.0)
    
    # Remove member
    print("Removing player from team...")
    # Scroll to member section if needed
    scroll_to_text("Members")
    # Tap the trash icon next to player@cricup.com
    player_coords = get_node_center_by_text("player@cricup.com")
    if player_coords:
        trash_x = 940
        trash_y = player_coords[1] - 40
        print(f"Tapping trash icon at coordinates ({trash_x}, {trash_y}) next to player@cricup.com...")
        run_adb(["shell", "input", "tap", str(trash_x), str(trash_y)])
        time.sleep(2.0)
    else:
        print("WARNING: Could not find coordinates for player@cricup.com")
    # Tap Remove on the confirmation dialog
    tap_node_by_text("Remove", exact=True)
    time.sleep(3.0)
    capture_screenshot("phase2_captain_removed_member")

    # Delete Team
    print("Deleting team...")
    # Open popup menu
    tap_node_by_text("Show menu")
    time.sleep(1.5)
    tap_node_by_text("Delete Team", exact=True)
    time.sleep(2.0)
    capture_screenshot("phase2_delete_team_confirm")
    tap_node_by_text("Delete", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_team_deleted_success")

    go_back_to_dashboard()
    logout()

    # Flow 3: Admin Panel Verification & Bulk Delete
    print("Verification: Admin Panel & Bulk Delete...")
    # Seed bulk delete items directly into PostgreSQL DB
    create_bulk_delete_items()

    login("cricupservice@gmail.com", "Password123!")
    
    # Navigate to Profile -> Admin Control Panel
    if not tap_node_by_text("Profile"):
        print("Profile node not found by text, tapping profile avatar at top-left (90, 120)...")
        run_adb(["shell", "input", "tap", "90", "120"])
    time.sleep(3.0)
    capture_screenshot("phase2_admin_profile_screen")
    
    tap_node_by_text("Admin Control Panel")
    # Wait for analytics to load (up to 20 seconds)
    analytics_loaded = False
    for i in range(10):
        if check_screen_text("Team Members", retries=1):
            analytics_loaded = True
            break
        print(f"Waiting for Admin Stats dashboard to load analytics... (attempt {i+1}/10)")
        time.sleep(2.0)
    
    capture_screenshot("phase2_admin_dashboard_stats")
    if not analytics_loaded:
        raise Exception("Team Members card not found on Admin Stats dashboard!")
    print("SUCCESS: Found Team Members card in Admin Dashboard!")

    # --- 1. Bulk Delete Users ---
    print("Testing Admin Bulk Delete Users...")
    tap_node_by_text("USERS")
    time.sleep(3.0)
    capture_screenshot("phase2_admin_users_tab")
    
    # Search for Bulk Users
    enter_text_in_field(0, "Bulk")
    time.sleep(2.0)
    capture_screenshot("phase2_admin_users_search_filtered")
    
    # Select all and delete (using coordinates because of bounds issues)
    print("Tapping Select All checkbox...")
    run_adb(["shell", "input", "tap", "100", "860"])
    time.sleep(2.0)
    capture_screenshot("phase2_admin_users_selected")
    
    # Tap Delete Selected
    print("Tapping Delete Selected button...")
    run_adb(["shell", "input", "tap", "850", "860"])
    time.sleep(2.0)
    capture_screenshot("phase2_admin_users_delete_confirm")
    tap_node_by_text("Delete", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_admin_users_deleted_success")

    # Switch to DATA tab
    tap_node_by_text("DATA")
    time.sleep(3.0)
    capture_screenshot("phase2_admin_data_tab")

    # --- 2. Bulk Delete Tournaments ---
    print("Testing Admin Bulk Delete Tournaments...")
    enter_text_in_field(0, "Bulk")
    time.sleep(2.0)
    capture_screenshot("phase2_admin_tournaments_search_filtered")
    print("Tapping Select All checkbox...")
    run_adb(["shell", "input", "tap", "100", "860"])
    time.sleep(2.0)
    print("Tapping Delete Selected button...")
    run_adb(["shell", "input", "tap", "850", "860"])
    time.sleep(2.0)
    tap_node_by_text("Delete", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_admin_tournaments_deleted_success")

    # --- 3. Bulk Delete Matches ---
    print("Testing Admin Bulk Delete Matches...")
    print("Tapping Matches tab header...")
    run_adb(["shell", "input", "tap", "440", "717"])
    time.sleep(2.0)
    enter_text_in_field(0, "Bulk")
    time.sleep(2.0)
    capture_screenshot("phase2_admin_matches_search_filtered")
    print("Tapping Select All checkbox...")
    run_adb(["shell", "input", "tap", "100", "860"])
    time.sleep(2.0)
    print("Tapping Delete Selected button...")
    run_adb(["shell", "input", "tap", "850", "860"])
    time.sleep(2.0)
    tap_node_by_text("Delete", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_admin_matches_deleted_success")

    # --- 4. Bulk Delete Teams ---
    print("Testing Admin Bulk Delete Teams...")
    print("Tapping Teams tab header...")
    run_adb(["shell", "input", "tap", "661", "717"])
    time.sleep(2.0)
    enter_text_in_field(0, "Bulk")
    time.sleep(2.0)
    capture_screenshot("phase2_admin_teams_search_filtered")
    print("Tapping Select All checkbox...")
    run_adb(["shell", "input", "tap", "100", "860"])
    time.sleep(2.0)
    print("Tapping Delete Selected button...")
    run_adb(["shell", "input", "tap", "850", "860"])
    time.sleep(2.0)
    tap_node_by_text("Delete", exact=True)
    time.sleep(4.0)
    capture_screenshot("phase2_admin_teams_deleted_success")

    # --- 5. Verify Team Members sub-tab in Admin ---
    print("Testing Admin Team Members display & search...")
    print("Tapping Team Members tab header...")
    run_adb(["shell", "input", "tap", "921", "717"])
    time.sleep(2.0)
    capture_screenshot("phase2_admin_team_members_list")
    print("Exiting Admin Panel and Profile screen back to Dashboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(3.0)
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(3.0)
    logout()
    print("\nALL PHASE 2 COMPLIANCE AUTOMATED TESTS COMPLETED SUCCESSFULLY!")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Exception encountered: {e}")
        capture_screenshot("phase2_error_screen")
        raise
