import urllib.request
import urllib.parse
import json
import time
import re
import random

PROD_URL = "https://cricket-tournament-production.up.railway.app/api/v1"
ADMIN_URL = "https://cricket-tournament-production.up.railway.app/admin"

def api_post(path, data_dict):
    url = f"{PROD_URL}{path}"
    data = json.dumps(data_dict).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        }
    )
    with urllib.request.urlopen(req) as res:
        return json.loads(res.read().decode("utf-8"))

def fetch_otp_by_user_id(user_id):
    details_url = f"{ADMIN_URL}/user/details/{user_id}"
    print(f"Fetching user details directly from: {details_url}")
    req = urllib.request.Request(details_url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as res:
            dcontent = res.read().decode('utf-8', errors='ignore')
            otp_match = re.search(r'<td>otp_code</td>\s*<td>(\d{6})</td>', dcontent, re.DOTALL | re.IGNORECASE)
            if otp_match:
                otp_val = otp_match.group(1)
                print(f"Found OTP Code: {otp_val}")
                return otp_val
    except Exception as e:
        print("Error fetching OTP:", e)
    return None

def main():
    rand_id = random.randint(100000, 999999)
    username = f"smoke_{rand_id}"
    email = f"{username}@gmail.com"
    password = "Password123!"
    
    print(f"Signing up user '{username}' on production backend...")
    signup_payload = {
        "username": username,
        "email": email,
        "password": password,
        "confirm_password": password
    }
    
    try:
        signup_res = api_post("/auth/signup", signup_payload)
        print("Signup success!", signup_res)
        user_id = signup_res['id']
    except urllib.error.HTTPError as e:
        print(f"Signup HTTP error: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
        return
    except Exception as e:
        print(f"Signup error: {e}")
        return
        
    # Give DB a second to commit
    time.sleep(1.5)
    
    # Retrieve OTP directly using user_id
    otp = fetch_otp_by_user_id(user_id)
    if not otp:
        print("Could not find OTP from admin details page.")
        return
        
    # Verify OTP
    print("Verifying OTP...")
    verify_payload = {
        "email": email,
        "otp_code": otp
    }
    try:
        verify_res = api_post("/auth/verify-otp", verify_payload)
        print("OTP verification success!", verify_res)
    except urllib.error.HTTPError as e:
        print(f"Verify OTP HTTP error: {e.code} - {e.read().decode('utf-8', errors='ignore')}")
        return
        
    # Save credentials
    creds = {
        "username": username,
        "email": email,
        "password": password
    }
    with open("scratch/prod_credentials.json", "w") as f:
        json.dump(creds, f)
        
    print("\nSUCCESS! Production test account created and verified.")
    print("Credentials saved to scratch/prod_credentials.json.")

if __name__ == "__main__":
    main()
