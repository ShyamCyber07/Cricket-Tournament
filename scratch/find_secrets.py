import json
import re

transcript_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\3251b567-d4c2-4a27-8bf8-5ba1908b9741\.system_generated\logs\transcript.jsonl"
print("Scanning transcript.jsonl...")

terms = ["railway", "postgres", "database", "pg_", "connection", "alembic", "secret", "env"]

with open(transcript_path, "r", encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        try:
            data = json.loads(line)
        except Exception:
            continue
        
        content_str = str(data)
        # check if any of the terms are present in the line (case insensitive)
        found = []
        for term in terms:
            if term in content_str.lower():
                found.append(term)
        
        if found:
            # check if it looks like a database URL or similar sensitive info, or railway deploy command
            # exclude generic stuff like pydantic schema or sqlalchemy files unless they contain actual values
            if "railway.app" in content_str or "postgresql://" in content_str or "postgres://" in content_str or "alembic upgrade" in content_str:
                print(f"--- MATCH AT LINE {i} (terms: {found}) ---")
                # print a subset of the data
                step_idx = data.get("step_index", i)
                source = data.get("source", "")
                type_ = data.get("type", "")
                content = data.get("content", "")
                tool_calls = data.get("tool_calls", [])
                print(f"Step: {step_idx} | Source: {source} | Type: {type_}")
                if content:
                    print(f"Content: {content[:500]}")
                if tool_calls:
                    print(f"Tool Calls: {str(tool_calls)[:500]}")
