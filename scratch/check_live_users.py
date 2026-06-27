import urllib.request
import json

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
base_url = "https://cricket-tournament-production.up.railway.app"

req = urllib.request.Request(
    f"{base_url}/api/v1/admin/users",
    headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}
)

try:
    with urllib.request.urlopen(req, timeout=10.0) as response:
        users = json.loads(response.read().decode())
        print("Users on live Railway:")
        for u in users:
            print(f"ID: {u.get('id')}, Email: {u.get('email')}, Username: {u.get('username')}, Role: {u.get('role')}")
except Exception as e:
    print(f"Error: {e}")
