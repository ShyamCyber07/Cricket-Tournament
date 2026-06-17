import subprocess
import time
import os
import re
import sys
import random
import string
import json
import urllib.request
import urllib.error
import imaplib
import email
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    stdout = res.stdout.decode('utf-8', errors='ignore')
    return stdout

def capture_screen(filename):
    dest = f"C:/Users/praja/.gemini/antigravity-ide/brain/17ed54b0-3f2c-41a7-9707-81edcd070e89/{filename}"
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot: {filename}")

def check_keyboard_and_dismiss():
    dumpsys = run_adb(["shell", "dumpsys", "input_method"])
    if "mInputShown=true" in dumpsys:
        print("Keyboard is shown, dismissing...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(1.5)

def clean_ethereal_inbox():
    print("Cleaning Ethereal inbox...")
    user = "nafa6ilszojywomn@ethereal.email"
    password = "uH9TnpaUep3an3eFqx"
    host = "imap.ethereal.email"
    try:
        mail = imaplib.IMAP4_SSL(host, 993)
        mail.login(user, password)
        mail.select("inbox")
        status, data = mail.search(None, "ALL")
        for num in data[0].split():
            mail.store(num, "+FLAGS", "\\Deleted")
        mail.expunge()
        mail.logout()
        print("Inbox cleaned successfully.")
    except Exception as e:
        print("Error cleaning inbox:", e)

def poll_ethereal_otp(to_email):
    print(f"Polling Ethereal IMAP for OTP sent to {to_email}...")
    user = "nafa6ilszojywomn@ethereal.email"
    password = "uH9TnpaUep3an3eFqx"
    host = "imap.ethereal.email"
    
    # Try polling for up to 60 seconds
    for attempt in range(30):
        try:
            mail = imaplib.IMAP4_SSL(host, 993)
            mail.login(user, password)
            mail.select("inbox")
            status, data = mail.search(None, "ALL")
            mail_ids = data[0].split()
            for num in reversed(mail_ids):
                status, fetch_data = mail.fetch(num, "(RFC822)")
                raw_email = fetch_data[0][1]
                msg = email.message_from_bytes(raw_email)
                msg_to = msg["To"]
                msg_subject = msg["Subject"]
                if to_email.lower() in msg_to.lower():
                    body = ""
                    if msg.is_multipart():
                        for part in msg.walk():
                            if part.get_content_type() == "text/plain":
                                body = part.get_payload(decode=True).decode()
                    else:
                        body = msg.get_payload(decode=True).decode()
                    
                    match = re.search(r'\b\d{6}\b', body)
                    if match:
                        otp_code = match.group(0)
                        print(f"SUCCESS: Found OTP code {otp_code} for {to_email} in subject '{msg_subject}'")
                        mail.logout()
                        return otp_code
            mail.logout()
        except Exception as e:
            print("IMAP Poll Exception (retrying):", e)
        time.sleep(2)
    print(f"ERROR: Could not find OTP for {to_email} in Ethereal inbox.")
    return None

def get_node_center_by_class(class_name, index=0):
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    try:
        root = ET.fromstring(xml_content)
        nodes = []
        for node in root.iter('node'):
            if node.get('class') == class_name:
                nodes.append(node)
        if index < len(nodes):
            bounds = nodes[index].get('bounds')
            m = re.findall(r'\d+', bounds)
            if len(m) == 4:
                x1, y1, x2, y2 = map(int, m)
                return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error parsing XML in get_node_center_by_class:", e)
    return None

def get_edit_text_value(index):
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    try:
        root = ET.fromstring(xml_content)
        edit_texts = []
        for node in root.iter('node'):
            if node.get('class') == 'android.widget.EditText':
                edit_texts.append(node)
        if index < len(edit_texts):
            return edit_texts[index].get('text')
    except Exception as e:
        print("Error in get_edit_text_value:", e)
    return None

def get_node_center_by_desc(content_desc):
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            if content_desc.lower() in node.get('content-desc', '').lower():
                bounds = node.get('bounds')
                m = re.findall(r'\d+', bounds)
                if len(m) == 4:
                    x1, y1, x2, y2 = map(int, m)
                    return (x1 + x2) // 2, (y1 + y2) // 2
    except Exception as e:
        print("Error parsing XML in get_node_center_by_desc:", e)
    return None

def check_screen_text(text_query):
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    return text_query.lower() in xml_content.lower()

def run_prod_e2e():
    clean_ethereal_inbox()
    
    random_str = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    email_address_intended = f"cricup_e2e_{random_str}@ethereal.email"
    username_intended = f"user_{random_str}"
    password = "Password123!"
    new_password = "NewPassword123!"
    
    # 0. Check initial screen
    if check_screen_text("Create Account"):
        print("Currently on Sign Up screen. Tapping Sign In link...")
        run_adb(["shell", "input", "tap", "763", "2233"]) # Sign In link
        time.sleep(3)
        
    if not check_screen_text("Welcome Back"):
        print("Not on Login screen. Tapping back or home to reset...")
        run_adb(["shell", "input", "keyevent", "4"])
        time.sleep(2)
        
    print("\n=== STEP 1: Navigate to Sign Up screen and fill details ===")
    # Tap Sign Up link on Login screen
    run_adb(["shell", "input", "tap", "740", "2189"])
    time.sleep(3)
    
    # Fill Username
    username_field = get_node_center_by_class("android.widget.EditText", 0) or (540, 859)
    run_adb(["shell", "input", "tap", str(username_field[0]), str(username_field[1])])
    time.sleep(1)
    run_adb(["shell", "input", "text", username_intended])
    time.sleep(1)
    
    # Fill Email (tab from username)
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(1)
    run_adb(["shell", "input", "text", email_address_intended])
    time.sleep(1)
    
    # Fill Password (tab from email)
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(1)
    run_adb(["shell", "input", "text", password])
    time.sleep(1)
    
    # Fill Confirm Password (tab twice)
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(0.5)
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(1)
    run_adb(["shell", "input", "text", password])
    time.sleep(1)
    
    check_keyboard_and_dismiss()
    
    # Read the actual values from UI to be 100% resilient to keyboard latency
    username = get_edit_text_value(0) or username_intended
    email_address = get_edit_text_value(1) or email_address_intended
    print(f"Actual username in field: {username}")
    print(f"Actual email in field: {email_address}")
    
    capture_screen("1_signup_filled.png")
    
    # Tap Sign Up button
    signup_btn = get_node_center_by_desc("Sign Up") or (540, 1998)
    run_adb(["shell", "input", "tap", str(signup_btn[0]), str(signup_btn[1])])
    print("Sign Up form submitted. Waiting for OTP screen...")
    
    # Since SMTP takes around 10 seconds, let's wait 15 seconds to be safe
    time.sleep(15)
    
    # Wait for OTP screen
    if not check_screen_text("Verification Code"):
        print("Failed to reach OTP screen. Retrying submit...")
        run_adb(["shell", "input", "tap", str(signup_btn[0]), str(signup_btn[1])])
        time.sleep(15)
        
    capture_screen("3_signup_otp_screen.png")
    
    # Retrieve OTP from Ethereal IMAP
    signup_otp = poll_ethereal_otp(email_address)
    if not signup_otp:
        print("ERROR: Signup OTP not received in inbox.")
        sys.exit(1)
        
    # Enter OTP
    first_otp_box = get_node_center_by_class("android.widget.EditText", 0) or (180, 1220)
    run_adb(["shell", "input", "tap", str(first_otp_box[0]), str(first_otp_box[1])])
    time.sleep(1)
    run_adb(["shell", "input", "text", signup_otp])
    print("Signup OTP entered. Waiting for OTP verification to complete...")
    time.sleep(6)
    
    capture_screen("3_signup_otp_verified.png")
    
    # Complete Profile (Full Name, Display Name)
    if check_screen_text("Get Started") or check_screen_text("Complete Profile"):
        print("Complete Profile screen displayed. Filling details...")
        fullname_field = get_node_center_by_class("android.widget.EditText", 0) or (540, 1000)
        run_adb(["shell", "input", "tap", str(fullname_field[0]), str(fullname_field[1])])
        time.sleep(1)
        run_adb(["shell", "input", "text", "E2E Test User"])
        time.sleep(1)
        
        # Tab to Display Name
        run_adb(["shell", "input", "keyevent", "61"])
        time.sleep(1)
        run_adb(["shell", "input", "text", f"Disp_{random_str}"])
        time.sleep(1)
        
        check_keyboard_and_dismiss()
        
        start_btn = get_node_center_by_desc("Get Started") or (540, 1980)
        run_adb(["shell", "input", "tap", str(start_btn[0]), str(start_btn[1])])
        time.sleep(5)
        
    capture_screen("4_dashboard_success.png")
    print("=== Dashboard Loaded Successfully ===")
    
    # Logout
    print("Logging out...")
    logout_btn = (1017, 210)
    run_adb(["shell", "input", "tap", str(logout_btn[0]), str(logout_btn[1])])
    time.sleep(4)
    
    # Verify login success with new credentials
    print("\n=== STEP 4: Login with newly created credentials ===")
    email_login_field = get_node_center_by_class("android.widget.EditText", 0) or (540, 1161)
    run_adb(["shell", "input", "tap", str(email_login_field[0]), str(email_login_field[1])])
    time.sleep(1)
    run_adb(["shell", "input", "text", email_address])
    time.sleep(1)
    
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(1)
    run_adb(["shell", "input", "text", password])
    time.sleep(1)
    
    check_keyboard_and_dismiss()
    
    signin_btn = get_node_center_by_desc("Sign In") or (540, 1631)
    run_adb(["shell", "input", "tap", str(signin_btn[0]), str(signin_btn[1])])
    print("Logging in...")
    time.sleep(5)
    
    capture_screen("5_login_success.png")
    
    # Logout for Forgot Password flow
    print("Logging out again...")
    run_adb(["shell", "input", "tap", str(logout_btn[0]), str(logout_btn[1])])
    time.sleep(4)
    
    # Respect rate limit of 60 seconds
    print("Waiting 65 seconds to respect the Forgot Password OTP rate limits...")
    time.sleep(65)
    
    # Step 5: Forgot Password
    print("\n=== STEP 5: Forgot Password flow ===")
    forgot_link = get_node_center_by_desc("Forgot Password?") or (809, 1480)
    run_adb(["shell", "input", "tap", str(forgot_link[0]), str(forgot_link[1])])
    time.sleep(4)
    
    # Enter email
    email_forgot_field = get_node_center_by_class("android.widget.EditText", 0) or (540, 1088)
    run_adb(["shell", "input", "tap", str(email_forgot_field[0]), str(email_forgot_field[1])])
    time.sleep(1)
    run_adb(["shell", "input", "text", email_address])
    time.sleep(1)
    
    check_keyboard_and_dismiss()
    capture_screen("5_forgot_password_email.png")
    
    send_code_btn = get_node_center_by_desc("Send Verification Code") or (540, 1500)
    run_adb(["shell", "input", "tap", str(send_code_btn[0]), str(send_code_btn[1])])
    print("Forgot Password request submitted. Waiting for OTP screen...")
    
    # Wait for OTP screen to appear (SMTP send takes about 10s)
    time.sleep(15)
    
    # Retrieve Reset OTP from Ethereal IMAP
    reset_otp = poll_ethereal_otp(email_address)
    if not reset_otp:
        print("ERROR: Reset OTP not received in inbox.")
        sys.exit(1)
        
    # Enter Reset OTP
    first_reset_otp_box = get_node_center_by_class("android.widget.EditText", 0) or (180, 1220)
    run_adb(["shell", "input", "tap", str(first_reset_otp_box[0]), str(first_reset_otp_box[1])])
    time.sleep(1)
    run_adb(["shell", "input", "text", reset_otp])
    print("Reset OTP entered. Waiting for OTP verification to complete...")
    time.sleep(5)
    
    # Reset Password Screen
    print("Setting new password...")
    new_pwd_field = get_node_center_by_class("android.widget.EditText", 0) or (540, 1164)
    run_adb(["shell", "input", "tap", str(new_pwd_field[0]), str(new_pwd_field[1])])
    time.sleep(1)
    run_adb(["shell", "input", "text", new_password])
    time.sleep(1)
    
    # Confirm Password (tab twice)
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(0.5)
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(1)
    run_adb(["shell", "input", "text", new_password])
    time.sleep(1)
    
    check_keyboard_and_dismiss()
    capture_screen("7_reset_password_filled.png")
    
    update_pwd_btn = get_node_center_by_desc("Update Password") or (540, 1981)
    run_adb(["shell", "input", "tap", str(update_pwd_btn[0]), str(update_pwd_btn[1])])
    print("Reset password submitted.")
    time.sleep(5)
    
    capture_screen("8_password_reset_success.png")
    
    # Go Back to Login
    back_to_login = get_node_center_by_desc("Back to Login") or (540, 1981)
    run_adb(["shell", "input", "tap", str(back_to_login[0]), str(back_to_login[1])])
    time.sleep(4)
    
    # Try Login with new password
    print("Logging in with new password...")
    email_login_field = get_node_center_by_class("android.widget.EditText", 0) or (540, 1161)
    run_adb(["shell", "input", "tap", str(email_login_field[0]), str(email_login_field[1])])
    time.sleep(1)
    
    # Clear old email/username
    run_adb(["shell", "input", "keyevent", "29", "--meta", "117"]) # Ctrl+A
    time.sleep(0.5)
    run_adb(["shell", "input", "keyevent", "67"]) # Backspace
    time.sleep(0.5)
    run_adb(["shell", "input", "text", email_address])
    time.sleep(1)
    
    run_adb(["shell", "input", "keyevent", "61"])
    time.sleep(1)
    run_adb(["shell", "input", "text", new_password])
    time.sleep(1)
    
    check_keyboard_and_dismiss()
    capture_screen("9_login_new_password.png")
    
    run_adb(["shell", "input", "tap", str(signin_btn[0]), str(signin_btn[1])])
    time.sleep(5)
    
    capture_screen("9_new_password_login_success.png")
    
    # Logout
    print("Logging out...")
    run_adb(["shell", "input", "tap", str(logout_btn[0]), str(logout_btn[1])])
    time.sleep(4)
    
    # Google Sign-In Success
    print("\n=== STEP 7: Google Sign-In ===")
    google_btn = get_node_center_by_desc("Continue with Google") or (540, 1995)
    run_adb(["shell", "input", "tap", str(google_btn[0]), str(google_btn[1])])
    print("Tapped Continue with Google. Waiting for login...")
    time.sleep(5)
    
    capture_screen("10_google_signin_success.png")
    
    print("\nE2E Verification script completed successfully!")

if __name__ == "__main__":
    run_prod_e2e()
