import os
import re

base_dir = r"C:\Users\praja\.gemini\antigravity-ide\brain\570c5832-ec96-4900-a8dd-d495effc011c"
workspace_dir = r"c:\Users\praja\Desktop\Cricket"
jwt_pattern = re.compile(r"eyJhbGciOi[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+")

print("Searching current conversation files and workspace for JWT tokens...")
found_tokens = set()

def search_dir(d):
    for root, dirs, files in os.walk(d):
        if "node_modules" in root or ".git" in root or ".venv" in root or "build" in root or "ios" in root or "android" in root:
            continue
        for file in files:
            if file.endswith(".jsonl") or file.endswith(".txt") or file.endswith(".log") or file.endswith(".py") or file.endswith(".json") or file.endswith(".dart"):
                path = os.path.join(root, file)
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read()
                        matches = jwt_pattern.findall(content)
                        for m in matches:
                            if m not in found_tokens:
                                found_tokens.add(m)
                                print(f"Found Token in {path}: {m[:35]}...")
                except Exception:
                    pass

search_dir(base_dir)
search_dir(workspace_dir)

print(f"\nTotal unique tokens found: {len(found_tokens)}")
for t in found_tokens:
    print(t)
