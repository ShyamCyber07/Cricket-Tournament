import subprocess
import os
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB, "-s", "f35c3099"] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    run_adb(["pull", "/sdcard/curr.xml", "curr.xml"])
    if not os.path.exists("curr.xml"):
        print("Failed to pull XML")
        return
        
    root = ET.parse("curr.xml").getroot()
    print("=== Clickable Elements ===")
    for node in root.iter("node"):
        if node.get("clickable") == "true" or node.get("focusable") == "true":
            text = node.get("text", "")
            desc = node.get("content-desc", "")
            cls = node.get("class", "")
            bounds = node.get("bounds", "")
            try:
                print(f"Text: '{text}', Desc: '{desc}', Class: '{cls}', Bounds: '{bounds}'")
            except UnicodeEncodeError:
                safe_text = text.encode('ascii', errors='replace').decode('ascii')
                safe_desc = desc.encode('ascii', errors='replace').decode('ascii')
                print(f"Text: '{safe_text}', Desc: '{safe_desc}', Class: '{cls}', Bounds: '{bounds}'")

if __name__ == "__main__":
    main()
