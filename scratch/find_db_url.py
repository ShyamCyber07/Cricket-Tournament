import os
import re
import json

base_dir = r"C:\Users\praja\.gemini\antigravity-ide\brain"
url_pattern = re.compile(r"postgresql?://[^\s\"']+", re.IGNORECASE)

print("Searching all transcript.jsonl files for PostgreSQL URLs...")
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file == "transcript.jsonl":
            path = os.path.join(root, file)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    for line_num, line in enumerate(f, 1):
                        urls = url_pattern.findall(line)
                        for url in urls:
                            if "postgres.railway.internal" not in url and "127.0.0.1" not in url and "localhost" not in url:
                                print(f"Found URL in {path}:{line_num}: {url}")
            except Exception as e:
                pass
