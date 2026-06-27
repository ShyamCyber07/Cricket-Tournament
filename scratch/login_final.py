import subprocess
import time
import os

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def enter_text_in_field(field_index, text_val, wait_secs=1):
    # Get EditText index field bounds
    # (Since we know Y is around 1214 for 0 and 1423 for 1, let's just use coordinates directly for maximum speed and reliability!)
    coords = [ (540, 1214), (540, 1423) ]
    x, y = coords[field_index]
    
    print(f"Tapping field {field_index} at ({x}, {y})...")
    run_adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(0.5)
    
    print("Clearing field...")
    clear_keys = ["123"] + ["67"] * 40
    run_adb(["shell", "input", "keyevent"] + clear_keys)
    time.sleep(0.5)
    
    print(f"Typing value: {text_val}")
    escaped_val = text_val.replace(" ", "%s")
    run_adb(["shell", "input", "text", escaped_val])
    time.sleep(wait_secs)

def main():
    print("Starting final login sequence...")
    # Enter email
    enter_text_in_field(0, "cricupservice@gmail.com")
    
    # Enter password
    enter_text_in_field(1, "Password123!")
    
    # Dismiss keyboard
    print("Dismissing keyboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.0)
    
    # Tap Sign In
    print("Tapping Sign In...")
    run_adb(["shell", "input", "tap", "540", "1727"])
    time.sleep(6.0)
    
    print("Login sequence finished.")

if __name__ == "__main__":
    main()
