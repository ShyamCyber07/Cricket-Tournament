import subprocess
import time
import os
import xml.etree.ElementTree as ET
import re
import sqlite3

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\3251b567-d4c2-4a27-8bf8-5ba1908b9741"
DB_PATH = r"c:\Users\praja\Desktop\Cricket\backend\cricket.db"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def get_screen_nodes():
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/curr.xml"])
    if not xml_content.strip() or "hierarchy" not in xml_content:
        return []
    try:
        root = ET.fromstring(xml_content)
        return list(root.iter('node'))
    except Exception as e:
        print("Error parsing XML:", e)
        return []

def get_node_center(node):
    bounds = node.get('bounds')
    m = re.findall(r'\d+', bounds)
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def find_node_by_text(text_query):
    nodes = get_screen_nodes()
    for n in nodes:
        t = n.get('text', '').lower()
        d = n.get('content-desc', '').lower()
        if text_query.lower() in t or text_query.lower() in d:
            return n
    return None

def wait_for_node_by_text(text_query, max_retries=10, delay=2):
    print(f"Waiting for node containing '{text_query}'...")
    for i in range(max_retries):
        node = find_node_by_text(text_query)
        if node is not None:
            return node
        time.sleep(delay)
    return None

def enter_text_in_field(field_index, text_val):
    nodes = get_screen_nodes()
    edit_texts = [n for n in nodes if n.get('class') == 'android.widget.EditText']
    if field_index < len(edit_texts):
        node = edit_texts[field_index]
        coords = get_node_center(node)
        if coords:
            # Tap field
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
            time.sleep(0.5)
            # Clear field
            clear_keys = ["123"] + ["67"] * 30
            run_adb(["shell", "input", "keyevent"] + clear_keys)
            # Type
            escaped_val = text_val.replace(" ", "%s")
            run_adb(["shell", "input", "text", f"'{escaped_val}'"])
            time.sleep(0.5)
            # Close keyboard
            run_adb(["shell", "input", "keyevent", "4"])
            time.sleep(0.5)
            return True
    return False

def click_button_with_text(text_query):
    node = wait_for_node_by_text(text_query, max_retries=5, delay=1.5)
    if node is not None:
        coords = get_node_center(node)
        print(f"Clicking '{text_query}' at {coords}")
        run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
        return True
    return False

def capture_screenshot(filename):
    path = os.path.join(ARTIFACTS_DIR, filename)
    print(f"Capturing screenshot to {path}...")
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", path])

def reset_db_rate_limits():
    print("Resetting database OTP rates...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET last_otp_sent_at = NULL")
    conn.commit()
    conn.close()

def get_user_otp(email):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT otp_code FROM users WHERE email = ?", (email,))
    row = cursor.fetchone()
    conn.close()
    return row[0] if row else None

def expire_user_otp(email):
    print(f"Expiring OTP in database for {email}...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET otp_expiry = '2020-01-01 00:00:00' WHERE email = ?", (email,))
    conn.commit()
    conn.close()

def main():
    print("=== STARTING EXPIRED OTP DIAGNOSTICS AND CAPTURE ===")
    
    # Force-stop app to ensure clean startup
    print("Force-stopping app...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.0)
    
    # Relaunch app
    print("Launching app...")
    run_adb(["shell", "monkey", "-p", "com.cricup", "-c", "android.intent.category.LAUNCHER", "1"])
    
    # Wait for welcome screen
    welcome_node = wait_for_node_by_text("Forgot Password?", max_retries=10, delay=2)
    if welcome_node is None:
        print("Failed to load Welcome Screen!")
        return

    # Request reset OTP for cricupservice@gmail.com
    print("Navigating to forgot password...")
    click_button_with_text("Forgot Password?")
    
    # Wait for Forgot Password screen to load
    email_label = wait_for_node_by_text("Send Verification Code", max_retries=10, delay=1.5)
    if email_label is None:
        print("Failed to load Forgot Password screen!")
        return
        
    print("Entering email...")
    enter_text_in_field(0, "cricupservice@gmail.com")
    reset_db_rate_limits()
    
    print("Clicking Send Verification Code...")
    click_button_with_text("Send Verification Code")
    time.sleep(3.0)

    # Get OTP from DB
    otp = get_user_otp("cricupservice@gmail.com")
    print(f"Retrieved reset OTP from DB: {otp}")

    if otp and len(otp) == 6:
        # Enter OTP
        print("Entering OTP...")
        nodes = get_screen_nodes()
        edit_texts = [n for n in nodes if n.get('class') == 'android.widget.EditText']
        if len(edit_texts) > 0:
            coords = get_node_center(edit_texts[0])
            run_adb(["shell", "input", "tap", str(coords[0]), str(coords[1])])
            time.sleep(0.5)
            # Type entire OTP in one command
            run_adb(["shell", "input", "text", otp])
            time.sleep(4.0) # Wait for transition
        
        # Wait for ResetPasswordScreen to load
        update_pwd_btn = wait_for_node_by_text("Update Password", max_retries=10, delay=1.5)
        if update_pwd_btn is None:
            print("Failed to load Reset Password screen!")
            return

        # Expire OTP in DB right now before submitting Reset Password
        expire_user_otp("cricupservice@gmail.com")

        # Now fill Reset Password fields and click Update Password
        print("Entering new passwords...")
        enter_text_in_field(0, "Password123@")
        enter_text_in_field(1, "Password123@")
        
        print("Clicking Update Password...")
        click_button_with_text("Update Password")
        time.sleep(2.5)
        
        capture_screenshot("reset_password_error.png")
    else:
        print("Failed to retrieve reset OTP from database!")

    print("=== EXPIRED OTP DIAGNOSTICS COMPLETED ===")

if __name__ == "__main__":
    main()
