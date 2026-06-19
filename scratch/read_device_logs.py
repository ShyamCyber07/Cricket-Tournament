import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    print("Dumping logcat logs...")
    logs = run_adb(["logcat", "-d"])
    
    print("\nRecent CricUP network logs:")
    lines = logs.splitlines()
    # Let's search for lines containing 'cricup', 'dio', 'request', 'response', or 'error'
    matching_lines = []
    for line in lines[-200:]: # check the last 200 lines
        if any(w in line.lower() for w in ["cricup", "dio", "error", "exception", "failed"]):
            matching_lines.append(line)
            
    for line in matching_lines[-50:]: # show last 50 matches
        print(line)

if __name__ == "__main__":
    main()
