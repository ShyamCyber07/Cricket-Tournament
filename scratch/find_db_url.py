import re
import os

log_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\01eabe81-72bf-4d1a-b7c0-b4dbd3b4d008\.system_generated\logs\transcript.jsonl"
full_log_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\01eabe81-72bf-4d1a-b7c0-b4dbd3b4d008\.system_generated\logs\transcript_full.jsonl"

def search_file(path):
    if not os.path.exists(path):
        print(f"File {path} does not exist")
        return
    print(f"Searching in {path}...")
    with open(path, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            if "rlwy" in line or "thomas" in line:
                # Find all occurrences of postgresql:// or database URL pattern
                matches = re.findall(r"postgresql://[^\s\"']+", line)
                if matches:
                    print(f"Line {i} matches:")
                    for m in matches:
                        print("  ", m)

search_file(log_path)
search_file(full_log_path)
