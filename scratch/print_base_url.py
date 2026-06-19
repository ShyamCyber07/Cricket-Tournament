import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    logs = run_adb(["logcat", "-d"])
    for line in logs.splitlines():
        if "BASE_URL=" in line:
            print("FOUND BASE URL LINE:", line)

if __name__ == "__main__":
    main()
