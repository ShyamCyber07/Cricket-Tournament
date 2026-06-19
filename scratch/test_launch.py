import subprocess
import os
import time

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout

print("Force stopping com.cricup...")
run_adb(["shell", "am", "force-stop", "com.cricup"])
time.sleep(2)

print("Launching com.cricup using am start...")
launch_out = run_adb(["shell", "am", "start", "-W", "-n", "com.cricup/com.cricup.MainActivity"])
print("Launch output:", launch_out)
time.sleep(3)

print("Reading resumed activity and focus lines in lower case:")
out = run_adb(["shell", "dumpsys", "activity", "activities"])
lines = out.splitlines()
is_foreground = any("mcurrentfocus" in line.lower() and "com.cricup" in line.lower() for line in lines)
print("is_foreground (mcurrentfocus + com.cricup):", is_foreground)
for line in lines:
    if "focus" in line.lower():
        print(f"MATCH: {repr(line.lower())}")
        print(f"  has mcurrentfocus: {'mcurrentfocus' in line.lower()}")
        print(f"  has com.cricup: {'com.cricup' in line.lower()}")


