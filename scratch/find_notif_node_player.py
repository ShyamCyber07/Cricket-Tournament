import os
import time
import xml.etree.ElementTree as ET
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

tree = ET.parse("player_dash.xml")
root = tree.getroot()

print("--- ALL NODES IN HEADER AREA ---")
for node in root.iter("node"):
    bounds = node.get("bounds", "")
    m = re.findall(r"\d+", bounds)
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        if cy < 320:
            desc = node.get('content-desc', '')
            text = node.get('text', '')
            print(f"Node: class={node.get('class')} | desc='{desc}' | text='{text}' | Center=({cx}, {cy}) | Bounds={bounds}")
