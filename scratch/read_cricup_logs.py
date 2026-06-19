import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

import sys

def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        pass
    print("Dumping logcat...")
    logs = run_adb(["logcat", "-d"])
    
    print("\nFiltering for Flutter and CricUP logs...")
    lines = logs.splitlines()
    matching = []
    for line in lines:
        if "flutter" in line.lower() or "com.cricup" in line.lower():
            matching.append(line)
            
    print(f"Total matching lines: {len(matching)}")
    # Print the last 80 lines
    for line in matching[-80:]:
        print(line)

if __name__ == "__main__":
    main()
