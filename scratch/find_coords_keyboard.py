import subprocess
import time
import os
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Force stopping com.cricup...")
    run_adb(["shell", "am", "force-stop", "com.cricup"])
    time.sleep(1.0)
    
    print("Launching com.cricup...")
    run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
    time.sleep(6.0)

    # Tap Email field at (540, 1100) to open keyboard
    print("Tapping Email field to open keyboard...")
    run_adb(["shell", "input", "tap", "540", "1100"])
    time.sleep(3.0)

    # Dump XML while keyboard is open
    print("Dumping UI hierarchy while keyboard is open...")
    run_adb(["shell", "uiautomator", "dump", "/sdcard/keyboard.xml"])
    run_adb(["pull", "/sdcard/keyboard.xml", "scratch/keyboard.xml"])
    
    # Parse XML and print EditText bounds
    tree = ET.parse("scratch/keyboard.xml")
    root = tree.getroot()
    
    print("\n--- EditText Nodes ---")
    for i, node in enumerate(root.iter('node')):
        if 'EditText' in node.get('class'):
            print(f"Index {i} | Class: {node.get('class')} | Bounds: {node.get('bounds')}")
            
    print("\n--- All Clickable Nodes ---")
    for i, node in enumerate(root.iter('node')):
        desc = node.get('content-desc', '')
        text = node.get('text', '')
        if (desc or text) and node.get('clickable') == 'true':
            print(f"Class: {node.get('class')} | Text: '{text}' | Desc: '{desc}' | Bounds: {node.get('bounds')}")

if __name__ == "__main__":
    main()
