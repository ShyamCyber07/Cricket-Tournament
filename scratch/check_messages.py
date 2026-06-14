import urllib.request
import json
import sys

headers = {
    "User-Agent": "Mozilla/5.0",
    "Accept": "application/json"
}

email = "cricup_e2e_fl19ecn8@web-library.net"
password = "TempPassword123!"

# Get mail.tm token
print("Getting mail.tm token...")
token_url = "https://api.mail.tm/token"
account_data = {"address": email, "password": password}
req = urllib.request.Request(
    token_url,
    data=json.dumps(account_data).encode("utf-8"),
    headers={"content-type": "application/json", "User-Agent": "Mozilla/5.0"}
)
try:
    with urllib.request.urlopen(req) as res:
        token_resp = json.loads(res.read().decode())
        token = token_resp["token"]
        print("Token acquired successfully.")
except Exception as e:
    print("Failed to acquire token:", e)
    sys.exit(1)

mail_headers = headers.copy()
mail_headers["Authorization"] = f"Bearer {token}"

# Check messages
check_url = "https://api.mail.tm/messages"
check_req = urllib.request.Request(check_url, headers=mail_headers)
try:
    with urllib.request.urlopen(check_req) as res:
        messages_resp = json.loads(res.read().decode())
        messages = messages_resp if isinstance(messages_resp, list) else messages_resp.get("hydra:member", [])
        print("Number of messages in inbox:", len(messages))
        for idx, msg in enumerate(messages):
            print(f"Message {idx+1}: Subject: {msg.get('subject')}, From: {msg.get('from')}")
            # Get message details
            read_url = f"https://api.mail.tm/messages/{msg['id']}"
            read_req = urllib.request.Request(read_url, headers=mail_headers)
            with urllib.request.urlopen(read_req) as read_res:
                details = json.loads(read_res.read().decode())
                print("Body:", details.get("text") or details.get("html"))
except Exception as e:
    print("Error checking messages:", e)
