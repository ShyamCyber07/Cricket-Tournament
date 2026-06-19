import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")

print("Checking for device f35c3099 authorization...")
for i in range(20):
    try:
        output = subprocess.check_output([ADB, "devices"]).decode()
        print(f"[{i+1}/20] Current adb devices output:\n{output.strip()}")
        if "f35c3099\tdevice" in output:
            print("Device f35c3099 is AUTHORIZED and ready!")
            exit(0)
        elif "f35c3099" not in output:
            print("Device f35c3099 is disconnected.")
    except Exception as e:
        print(f"Error checking devices: {e}")
    time.sleep(3)

print("Timeout waiting for device authorization. Please ensure USB debugging is enabled and authorized.")
exit(1)
