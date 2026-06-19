import os
import re

FEATURES_DIR = r"c:\Users\praja\Desktop\Cricket\frontend\lib\features"
CORE_DIR = r"c:\Users\praja\Desktop\Cricket\frontend\lib\core"

WIDGET_PATTERNS = {
    "ElevatedButton": re.compile(r"\bElevatedButton\b"),
    "TextButton": re.compile(r"\bTextButton\b"),
    "OutlinedButton": re.compile(r"\bOutlinedButton\b"),
    "IconButton": re.compile(r"\bIconButton\b"),
    "FloatingActionButton": re.compile(r"\bFloatingActionButton\b"),
    "PopupMenuButton": re.compile(r"\bPopupMenuButton\b"),
    "DropdownButton": re.compile(r"\bDropdownButton\b"),
    "DropdownButtonFormField": re.compile(r"\bDropdownButtonFormField\b"),
    "ChoiceChip": re.compile(r"\bChoiceChip\b"),
    "ListTile": re.compile(r"\bListTile\b"),
    "GestureDetector": re.compile(r"\bGestureDetector\b"),
    "InkWell": re.compile(r"\bInkWell\b"),
}

inventory = {}
total_counts = {k: 0 for k in WIDGET_PATTERNS.keys()}

def scan_file(filepath):
    rel_path = os.path.relpath(filepath, r"c:\Users\praja\Desktop\Cricket\frontend")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    file_matches = {}
    for name, pattern in WIDGET_PATTERNS.items():
        matches = list(pattern.finditer(content))
        if matches:
            file_matches[name] = len(matches)
            total_counts[name] += len(matches)
            
    if file_matches:
        inventory[rel_path] = file_matches

def scan_dir(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                scan_file(os.path.join(root, file))

scan_dir(FEATURES_DIR)
scan_dir(CORE_DIR)

print("=== CRIUP WIDGET INVENTORY SUMMARY ===")
for widget, count in total_counts.items():
    print(f"{widget}: {count}")

print("\n=== DETAIL BY FILE ===")
for file, widgets in sorted(inventory.items()):
    print(f"\nFile: {file}")
    for widget, count in widgets.items():
        print(f"  - {widget}: {count}")

print(f"\nTotal Interactive Elements: {sum(total_counts.values())}")
