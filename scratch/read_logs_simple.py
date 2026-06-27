import re

with open("scratch/google_tap_logcat.txt", "r", encoding="utf-8") as f:
    content = f.read()

print("Log file size:", len(content))
lines = content.splitlines()

# Search for flutter case-insensitively
pattern = re.compile(r"flutter|cricup|dio|http", re.IGNORECASE)
matches = [line for line in lines if pattern.search(line)]

print(f"Found {len(matches)} matching lines:")
for line in matches[:100]:
    print(line)
