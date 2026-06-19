import json
import re

transcript_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\3251b567-d4c2-4a27-8bf8-5ba1908b9741\.system_generated\logs\transcript.jsonl"
print("Scanning current transcript.jsonl for flutter path...")

with open(transcript_path, "r", encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        try:
            data = json.loads(line)
        except Exception:
            continue
        
        content_str = str(data)
        if "flutter" in content_str.lower():
            tool_calls = data.get("tool_calls", [])
            for tc in tool_calls:
                cmd = tc.get("args", {}).get("CommandLine", "")
                if "flutter" in cmd.lower():
                    print(f"Line {i}: {cmd}")
