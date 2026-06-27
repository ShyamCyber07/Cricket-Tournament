import os
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    return os.popen(" ".join(cmd)).read()

print("Force stopping CricUp...")
run_adb(["shell", "am", "force-stop", "com.cricup"])
time.sleep(1.0)

print("Launching CricUp...")
launch_res = run_adb(["shell", "am", "start", "-n", "com.cricup/com.cricup.MainActivity"])
print("Launch output:", launch_res.strip())
time.sleep(5.0)

print("Current focus:")
focus = run_adb(["shell", "dumpsys window | grep mCurrentFocus"])
print(focus.strip())

print("Capturing screenshot to scratch/app_launch_debug.png...")
run_adb(["shell", "screencap", "-p", "/data/local/tmp/launch_debug.png"])
run_adb(["pull", "/data/local/tmp/launch_debug.png", "scratch/app_launch_debug.png"])
