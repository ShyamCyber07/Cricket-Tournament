file_path = r"c:\Users\praja\Desktop\Cricket\frontend\lib\features\matches\screens\scoring_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

import re
print("Occurrences of 'partnership':", len(re.findall(r'partnership', content, re.IGNORECASE)))
print("Occurrences of 'run rate':", len(re.findall(r'run rate', content, re.IGNORECASE)))
print("Occurrences of 'commentary':", len(re.findall(r'commentary', content, re.IGNORECASE)))
print("Occurrences of 'Spacer':", len(re.findall(r'Spacer', content, re.IGNORECASE)))
