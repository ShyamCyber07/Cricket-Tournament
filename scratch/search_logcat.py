import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    log = run_adb(["logcat", "-d"])
    keywords = [
        "googleUser.email",
        "googleAuth.idToken",
        "idToken length",
        "exact token sent to backend",
        "DIAGNOSTICS",
        "PlatformException",
        "Exception",
        "google_login",
        "googleAuth.accessToken"
    ]
    
    print("=== SEARCH RESULTS ===")
    lines = log.splitlines()
    for line in lines:
        for kw in keywords:
            if kw.lower() in line.lower():
                print(line)
                break

if __name__ == "__main__":
    main()
