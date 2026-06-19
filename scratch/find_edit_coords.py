import subprocess
import os
import xml.etree.ElementTree as ET
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def dump_xml():
    run_adb(["shell", "rm", "-f", "/sdcard/window_dump.xml"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    return content

def main():
    print("Dumping XML from device...")
    xml_content = dump_xml()
    if not xml_content.strip():
        print("Empty XML content returned.")
        return
    
    # Save a copy to inspect
    with open("scratch/dump.xml", "w", encoding="utf-8") as f:
        f.write(xml_content)
    
    print("Parsing XML and searching for nodes...")
    try:
        root = ET.fromstring(xml_content)
        for node in root.iter('node'):
            cls = node.get('class')
            text = node.get('text')
            desc = node.get('content-desc')
            bounds = node.get('bounds')
            
            # Print if it has some potential for being the edit button or header element
            if "Button" in cls or "Image" in cls or text or desc:
                print(f"Class: {cls} | Text: {text!r} | Desc: {desc!r} | Bounds: {bounds}")
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
