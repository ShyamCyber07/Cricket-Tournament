import os
import time
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    return os.popen(" ".join(cmd)).read()

print("Dumping Player Dashboard UI hierarchy...")
run_adb(["shell", "uiautomator", "dump", "/data/local/tmp/player_dash.xml"])
run_adb(["pull", "/data/local/tmp/player_dash.xml", "player_dash.xml"])

tree = ET.parse("player_dash.xml")
root = tree.getroot()

for node in root.iter("node"):
    text = node.get("text", "")
    desc = node.get("content-desc", "")
    bounds = node.get("bounds", "")
    if text or desc:
        print(f"Node: text='{text}' | desc='{desc}' | class={node.get('class')} | bounds={bounds}")
