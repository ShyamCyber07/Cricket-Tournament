import subprocess
import os
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
ARTIFACTS_DIR = r"C:\Users\praja\.gemini\antigravity-ide\brain\570c5832-ec96-4900-a8dd-d495effc011c"

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Tapping Add Team FAB...")
    run_adb(["shell", "input", "tap", "959", "2260"])
    time.sleep(2)
    
    print("Dumping UI hierarchy...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/curr.xml"])
    run_adb(["pull", "/sdcard/curr.xml", "curr.xml"])
    
    print("Capturing screenshot...")
    dest = os.path.join(ARTIFACTS_DIR, "curr_screen.png")
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", dest])
    print(f"Captured screenshot to: {dest}")
    
    # Print clickable nodes
    import xml.etree.ElementTree as ET
    if os.path.exists("curr.xml"):
        root = ET.parse("curr.xml").getroot()
        print("=== Clickable / Focusable Elements ===")
        for node in root.iter("node"):
            if node.get("clickable") == "true" or node.get("focusable") == "true" or node.get("class") == "android.widget.EditText":
                text = node.get("text", "")
                desc = node.get("content-desc", "")
                cls = node.get("class", "")
                bounds = node.get("bounds", "")
                print(f"Text: '{text}', Desc: '{desc}', Class: '{cls}', Bounds: '{bounds}'")

if __name__ == "__main__":
    main()
