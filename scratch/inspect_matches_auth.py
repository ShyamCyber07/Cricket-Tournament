file_path = r"c:\Users\praja\Desktop\Cricket\backend\app\routers\matches.py"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    line_num = i + 1
    if 'created_by' in line or 'organizer_id' in line or 'authorized' in line or 'status_code=403' in line:
        print(f"Line {line_num}: {line.strip()}")
