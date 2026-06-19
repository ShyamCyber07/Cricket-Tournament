import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

def run_adb(args):
    cmd = [ADB] + args
    subprocess.run(cmd)

if __name__ == "__main__":
    print("Dismissing dialog by tapping Cancel...")
    run_adb(["shell", "input", "tap", "433", "1600"])
