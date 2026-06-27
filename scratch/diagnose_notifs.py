import os
import time
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    return os.popen(" ".join(cmd)).read()

print("Launching and dumping UI...")
run_adb(["shell", "uiautomator", "dump", "/data/local/tmp/diagnose.xml"])
run_adb(["pull", "/data/local/tmp/diagnose.xml", "diagnose.xml"])

tree = ET.parse("diagnose.xml")
root = tree.getroot()
for node in root.iter("node"):
    text = node.get("text", "")
    desc = node.get("content-desc", "")
    if text or desc:
        print(f"Node: text='{text}' | desc='{desc}' | class={node.get('class')} | bounds={node.get('bounds')}")
