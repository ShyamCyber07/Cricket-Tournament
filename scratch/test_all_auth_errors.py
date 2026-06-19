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
    node = find_node_by_text(text_query)
    if node:
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
    print("=== STARTING UX AUTH ERROR DIAGNOSTICS AND CAPTURE ===")
    reset_db_rate_limits()

    # 1. TEST LOGIN ERROR
    print("\n--- TEST 1: Incorrect Login ---")
    enter_text_in_field(0, "incorrect@gmail.com")
    enter_text_in_field(1, "IncorrectPwd1!")
    click_button_with_text("Sign In")
    time.sleep(2.0)
    capture_screenshot("login_error.png")

    # 2. TEST FORGOT PASSWORD (USER NOT FOUND)
    print("\n--- TEST 2: Forgot Password User Not Found ---")
    click_button_with_text("Forgot Password?")
    time.sleep(1.5)
    enter_text_in_field(0, "nonexistent@gmail.com")
    click_button_with_text("Send Verification Code")
    time.sleep(2.0)
    capture_screenshot("forgot_password_error.png")

    # Go back to Welcome/Sign In screen
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.5)

    # 3. TEST SIGNUP (DUPLICATE EMAIL)
    print("\n--- TEST 3: Signup Duplicate Email ---")
    click_button_with_text("Sign Up")
    time.sleep(1.5)
    enter_text_in_field(0, "uniqueusername1")
    enter_text_in_field(1, "cricupservice@gmail.com")
    enter_text_in_field(2, "Password123@")
    enter_text_in_field(3, "Password123@")
    click_button_with_text("Sign Up")
    time.sleep(2.0)
    capture_screenshot("signup_duplicate_email.png")

    # 4. TEST SIGNUP (DUPLICATE USERNAME)
    print("\n--- TEST 4: Signup Duplicate Username ---")
    enter_text_in_field(0, "cricupservice")
    enter_text_in_field(1, "uniqueemail1@gmail.com")
    enter_text_in_field(2, "Password123@")
    enter_text_in_field(3, "Password123@")
    click_button_with_text("Sign Up")
    time.sleep(2.0)
    capture_screenshot("signup_duplicate_username.png")

    # 5. TEST SIGNUP (UNVERIFIED ACCOUNT)
    print("\n--- TEST 5: Signup Unverified Account ---")
    enter_text_in_field(0, "unverifieduser")
    enter_text_in_field(1, "unverified123@gmail.com")
    enter_text_in_field(2, "Password123@")
    enter_text_in_field(3, "Password123@")
    click_button_with_text("Sign Up")
    time.sleep(2.0)
    capture_screenshot("signup_unverified.png")

    # 6. TEST OTP VERIFICATION (INVALID OTP)
    print("\n--- TEST 6: Invalid OTP Verification ---")
    # Click "Verify Account" on the unverified account dialog
    click_button_with_text("Verify Account")
    time.sleep(2.0)
    # The VerifyOtpScreen has 6 single-character fields.
    # Tap each of the 6 EditText fields and enter "1"
    for i in range(6):
        enter_text_in_field(i, "1")
    time.sleep(2.0) # Submit automatically triggers, or click Verify OTP
    capture_screenshot("verify_otp_error.png")

    # Cancel and go back to Sign In
    # We will tap the Back button on the screen or send ADB keyevent 4 twice to return to Welcome
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.0)
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.0)

    # 7. TEST RESET PASSWORD (EXPIRED OTP)
    print("\n--- TEST 7: Expired Reset Password OTP ---")
    # Request reset OTP for cricupservice@gmail.com
    click_button_with_text("Forgot Password?")
    time.sleep(1.5)
    enter_text_in_field(0, "cricupservice@gmail.com")
    reset_db_rate_limits()
    click_button_with_text("Send Verification Code")
    time.sleep(2.5)

    # Get OTP from DB
    otp = get_user_otp("cricupservice@gmail.com")
    print(f"Retrieved reset OTP from DB: {otp}")

    # On ForgotPasswordOtpScreen, enter the correct OTP to progress to ResetPasswordScreen
    if otp and len(otp) == 6:
        for index, char in enumerate(otp):
            enter_text_in_field(index, char)
        time.sleep(3.5) # Wait for navigation to ResetPasswordScreen

        # Expire OTP in DB right now before submitting Reset Password
        expire_user_otp("cricupservice@gmail.com")

        # Now fill Reset Password fields and click Update Password
        enter_text_in_field(0, "Password123@")
        enter_text_in_field(1, "Password123@")
        click_button_with_text("Update Password")
        time.sleep(2.5)
        capture_screenshot("reset_password_error.png")

    print("\n=== DIAGNOSTICS AND CAPTURE COMPLETED ===")

if __name__ == "__main__":
    main()
