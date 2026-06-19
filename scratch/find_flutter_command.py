import json

log_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\55c5d66f-9b9f-4f87-92f4-55dfa487d321\.system_generated\logs\transcript.jsonl"

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            if 'tool_calls' in data:
                for tc in data['tool_calls']:
                    if tc.get('name') == 'run_command':
                        cmd = tc.get('args', {}).get('CommandLine', '')
                        if 'flutter' in cmd.lower() or 'apk' in cmd.lower():
                            print(f"Command found: {cmd}")
        except Exception as e:
            pass
