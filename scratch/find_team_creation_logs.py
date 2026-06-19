import subprocess
import os
import sys

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        pass
    print("Dumping logcat...")
    logs = run_adb(["logcat", "-d"])
    
    print("\nFiltering for team and logo network logs...")
    lines = logs.splitlines()
    matching = []
    capture = False
    for line in lines:
        # Check if line indicates starting or ending of a request for teams or logo
        if any(w in line for w in ["/teams", "/logo", "/tournaments"]):
            capture = True
        
        if capture:
            matching.append(line)
            if "Dio Response Data" in line or "Dio Response" in line:
                capture = False
                
    print(f"Matching logs count: {len(matching)}")
    for line in matching[-60:]:
        print(line)

if __name__ == "__main__":
    main()
