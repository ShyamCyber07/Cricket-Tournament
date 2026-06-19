import urllib.request
import json

url = "http://localhost:8000/api/v1/matches/"

try:
    req = urllib.request.Request(url)
    # The endpoint requires auth. Let's see if it returns 401 Unauthorized (which means the server is running and compiled fine!)
    # or 200/404/etc.
    with urllib.request.urlopen(req) as response:
        print("Response status:", response.status)
except urllib.error.HTTPError as e:
    print("HTTP Error code:", e.code)
    print("HTTP Error response headers:", e.headers)
except Exception as e:
    print("Connection failed:", e)
