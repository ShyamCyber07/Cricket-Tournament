import urllib.request
import urllib.parse
import json
import time
import re
import random

PROD_URL = "https://cricket-tournament-production.up.railway.app/api/v1"

def api_post(path, data_dict):
    url = f"{PROD_URL}{path}"
    data = json.dumps(data_dict).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as res:
        return json.loads(res.read().decode("utf-8"))

def fetch_otp(login, domain):
    print(f"Waiting for OTP email in {login}@{domain}...")
    url = f"https://www.1secmail.com/api/v1/?action=getMessages&login={login}&domain={domain}"
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    
    for attempt in range(15):
        time.sleep(3.0)
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req) as res:
                messages = json.loads(res.read().decode("utf-8"))
                if messages:
                    # Found a message! Let's read it
                    msg_id = messages[0]['id']
                    read_url = f"https://www.1secmail.com/api/v1/?action=readMessage&login={login}&domain={domain}&id={msg_id}"
                    read_req = urllib.request.Request(read_url, headers=headers)
                    with urllib.request.urlopen(read_req) as read_res:
                        msg = json.loads(read_res.read().decode("utf-8"))
                        body = msg['body']
                        
                        # Find 6-digit OTP code using regex
                        match = re.search(r'\b\d{6}\b', body)
                        if match:
                            otp = match.group(0)
                            print(f"Found OTP in email: {otp}")
                            return otp
        except Exception as e:
            print(f"Error checking mailbox: {e}")
            
    print("Failed to find OTP email.")
    return None

def main():
    rand_id = random.randint(100000, 999999)
    username = f"prod_friend_{rand_id}"
    email = f"{username}@1secmail.com"
    password = "Password123!"
    
    print(f"Generated user credentials:\nUsername: {username}\nEmail: {email}\nPassword: {password}\n")
    
    # 1. Signup
    print("Calling Signup API on production backend...")
    signup_payload = {
        "username": username,
        "email": email,
        "password": password,
        "confirm_password": password
    }
    
    try:
        signup_res = api_post("/auth/signup", signup_payload)
        print("Signup success!", signup_res)
    except urllib.error.HTTPError as e:
        print(f"Signup HTTP error: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
        return
    except Exception as e:
        print(f"Signup error: {e}")
        return
        
    # 2. Get OTP from 1secmail
    otp = fetch_otp(username, "1secmail.com")
    if not otp:
        return
        
    # 3. Verify OTP
    print("Calling Verify OTP API...")
    verify_payload = {
        "email": email,
        "otp_code": otp
    }
    try:
        verify_res = api_post("/auth/verify-otp", verify_payload)
        print("OTP verified success!", verify_res)
    except urllib.error.HTTPError as e:
        print(f"Verify OTP HTTP error: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
        return
        
    # Save the credentials to a file for the smoke test
    creds = {
        "username": username,
        "email": email,
        "password": password
    }
    with open("scratch/prod_credentials.json", "w") as f:
        json.dump(creds, f)
        
    print(f"\nSUCCESS! Account created and verified.\nSaved credentials to scratch/prod_credentials.json.")

if __name__ == "__main__":
    main()
