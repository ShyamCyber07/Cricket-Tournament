import socket
import time
import sys

print("Polling for internet connection to google.com:443...")
for i in range(60): # Poll for up to 5 minutes (60 * 5s)
    try:
        s = socket.socket()
        s.settimeout(3)
        s.connect(('google.com', 443))
        print("SUCCESS: Internet connection restored!")
        sys.exit(0)
    except Exception as e:
        print(f"Attempt {i+1}/60: Offline ({e})")
    time.sleep(5)

print("ERROR: Connection timed out. Still offline after 5 minutes.")
sys.exit(1)
