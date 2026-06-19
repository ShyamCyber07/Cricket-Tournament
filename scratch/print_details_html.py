import urllib.request

details_url = "https://cricket-tournament-production.up.railway.app/admin/user/details/29fbf723-b6a9-4808-a21f-f44210faa05b"
req = urllib.request.Request(details_url, headers={"User-Agent": "Mozilla/5.0"})

try:
    with urllib.request.urlopen(req) as res:
        content = res.read().decode('utf-8', errors='ignore')
        with open("scratch/user_details_prod.html", "w", encoding="utf-8") as f:
            f.write(content)
        print("HTML saved successfully to scratch/user_details_prod.html")
except Exception as e:
    print("Error:", e)
