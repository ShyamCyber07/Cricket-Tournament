import urllib.request
import json

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3ODI2MzY4NzYsInN1YiI6IjMxZjkyODllLWZiMGMtNGQ4Ni1iYWEyLTM3MDRkODI3OTZjYiJ9.1jl70ZC2l-Ouj5elNKccxPG34l7wHddZO3HwXGfcQE4"
headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/json"
}

def query_endpoint(path):
    url = f"https://cricket-tournament-production.up.railway.app/api/v1{path}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30.0) as resp:
            return resp.getcode(), json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return 500, str(e)

def main():
    print("1. Checking current database schema via /admin/debug-db ...")
    code, data = query_endpoint("/admin/debug-db")
    print(f"Response code: {code}")
    print("Response data:", json.dumps(data, indent=2))
    
    if code != 200:
        print("Failed to query debug-db.")
        return
        
    tables = data.get("tables", [])
    if "team_members" in tables:
        print("\nSUCCESS: 'team_members' table already exists!")
    else:
        print("\n'team_members' table is MISSING. Running migrations via /admin/run-migrate ...")
        m_code, m_data = query_endpoint("/admin/run-migrate")
        print(f"Migration Response code: {m_code}")
        print("Migration Output:", json.dumps(m_data, indent=2))
        
        print("\nVerifying database schema again via /admin/debug-db ...")
        v_code, v_data = query_endpoint("/admin/debug-db")
        print(f"Verification Response code: {v_code}")
        print("Verification Response data:", json.dumps(v_data, indent=2))

if __name__ == "__main__":
    main()
