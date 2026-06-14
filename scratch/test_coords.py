import xml.etree.ElementTree as ET
import subprocess
import os
import re

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    stdout = res.stdout.decode('utf-8', errors='ignore')
    return stdout

def dump_and_parse():
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    xml_content = run_adb(["shell", "cat", "/sdcard/window_dump.xml"])
    print("XML Length:", len(xml_content))
    try:
        root = ET.fromstring(xml_content)
        idx = 0
        for node in root.iter('node'):
            cls = node.get('class')
            desc = node.get('content-desc', '')
            text = node.get('text', '')
            bounds = node.get('bounds')
            if 'EditText' in cls or desc or text:
                print(f"Node {idx}: class={cls}, desc={desc}, text={text}, bounds={bounds}")
                idx += 1
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    dump_and_parse()
