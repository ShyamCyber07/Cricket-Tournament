import subprocess
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def main():
    run_adb(["shell", "screencap", "-p", "/sdcard/current_state.png"])
    run_adb(["pull", "/sdcard/current_state.png", "scratch/current_state.png"])
    print("Screenshot captured to scratch/current_state.png")

if __name__ == "__main__":
    main()
