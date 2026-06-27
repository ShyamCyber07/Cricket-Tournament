import urllib.request
import urllib.error
import json

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
base_url = "https://cricket-tournament-production.up.railway.app"

headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/json"
}

def verify():
    url_my = f"{base_url}/api/v1/teams/my-teams"
    req_my = urllib.request.Request(url_my, headers=headers)
    try:
        with urllib.request.urlopen(req_my, timeout=10.0) as resp:
            print("Status:", resp.getcode())
            print("Response:", resp.read().decode())
    except urllib.error.HTTPError as e:
        print("HTTP Error Code:", e.code)
        print("Error Body:", e.read().decode())
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    verify()
