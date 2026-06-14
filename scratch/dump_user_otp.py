import urllib.request
import re

url = "https://cricket-tournament-production.up.railway.app/admin/user/list"
req = urllib.request.Request(
    url,
    headers={"User-Agent": "Mozilla/5.0"}
)
try:
    with urllib.request.urlopen(req) as res:
        content = res.read().decode('utf-8', errors='ignore')
        print("Admin user list length:", len(content))
        # Look for the details URL. It usually looks like href="http://.../admin/user/details/{uuid}"
        # Let's search for all details/ links
        matches = re.findall(r'href="[^"]*details/([^"]+)"', content)
        print("Found detail IDs:", matches)
        
        # Let's request the details page for the first ID (which should be the most recently registered user)
        if matches:
            details_id = matches[0]
            details_url = f"https://cricket-tournament-production.up.railway.app/admin/user/details/{details_id}"
            print("Fetching details URL:", details_url)
            details_req = urllib.request.Request(details_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(details_req) as dres:
                dcontent = dres.read().decode('utf-8', errors='ignore')
                print("Details content length:", len(dcontent))
                # Print any td content or text containing OTP
                with open("C:/Users/praja/.gemini/antigravity-ide/brain/fb893936-c729-493d-a4f1-fbb421f2812f/scratch/user_details.html", "w", encoding="utf-8") as f:
                    f.write(dcontent)
                # Find OTP code or similar fields
                otp_match = re.search(r'otp_code.*?<td>(.*?)</td>', dcontent, re.DOTALL | re.IGNORECASE)
                if otp_match:
                    print("Raw OTP match:", otp_match.group(1))
                else:
                    # Let's just find all table data cells or key-value pairs
                    print("Could not find otp_code directly via regex.")
                    # Let's dump all table cells
                    cells = re.findall(r'<th>(.*?)</th>\s*<td>(.*?)</td>', dcontent, re.DOTALL)
                    for k, v in cells:
                        k_clean = re.sub(r'<[^>]*>', '', k).strip()
                        v_clean = re.sub(r'<[^>]*>', '', v).strip()
                        print(f"Field: {k_clean} -> {v_clean}")
except Exception as e:
    print("Error:", e)
