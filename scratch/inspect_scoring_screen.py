import re

file_path = r"c:\Users\praja\Desktop\Cricket\frontend\lib\features\matches\screens\scoring_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    line_num = i + 1
    if 'created_by' in line or '_isViewerMode' in line or 'isViewer' in line:
        print(f"Line {line_num}: {line.strip()}")
