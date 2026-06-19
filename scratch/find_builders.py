file_path = r"c:\Users\praja\Desktop\Cricket\frontend\lib\features\matches\screens\scoring_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if '_buildBatsmanRow' in line or '_buildExtraButton' in line:
        print(f"Line {i+1}: {line.strip()}")
