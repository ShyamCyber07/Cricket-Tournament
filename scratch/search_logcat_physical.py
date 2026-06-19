import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    # Retrieve the last 3000 lines of logcat
    log = run_adb(["logcat", "-d", "-t", "3000"])
    keywords = [
        "differentuser",
        "cricupservice",
        "signup",
        "Dio Request",
        "Dio Response",
        "Dio Error",
        "auth/google",
        "googleAuth",
        "googleUser",
        "exact token sent",
        "idToken length"
    ]
    
    print("=== TAIL LOGCAT SEARCH RESULTS ===")
    lines = log.splitlines()
    for line in lines:
        for kw in keywords:
            if kw.lower() in line.lower():
                print(line)
                break

if __name__ == "__main__":
    main()
