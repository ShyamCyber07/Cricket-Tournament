import urllib.request
import json

url = "https://api.nodemailer.com/user"
data = json.dumps({"requestor": "CricUP", "version": "1.0"}).encode("utf-8")
req = urllib.request.Request(
    url,
    data=data,
    headers={
        "User-Agent": "Mozilla/5.0",
        "Content-Type": "application/json"
    }
)
try:
    with urllib.request.urlopen(req) as res:
        resp = json.loads(res.read().decode())
        print("ETHEREAL ACCOUNT CREATED:")
        print(json.dumps(resp, indent=2))
except Exception as e:
    print("Error:", e)
