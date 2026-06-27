import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = os.popen(" ".join(cmd)).read()
    return res

print("Dumping UI hierarchy...")
run_adb(["shell", "uiautomator", "dump", "/data/local/tmp/dash.xml"])
run_adb(["pull", "/data/local/tmp/dash.xml", "dash.xml"])

tree = ET.parse("dash.xml")
root = tree.getroot()

for node in root.iter("node"):
    bounds = node.get("bounds", "")
    m = re.findall(r"\d+", bounds)
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        # Header is usually y < 250 and x > 800
        if cy < 250 and cx > 800:
            print(f"Node: class={node.get('class')} | desc={node.get('content-desc')} | text={node.get('text')} | Center=({cx}, {cy}) | Bounds={bounds}")
