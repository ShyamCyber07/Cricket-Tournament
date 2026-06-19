import subprocess
import time
import os
import sys

# Ensure UTF-8 output if possible, but to be completely safe, we'll avoid print unicode chars
sys.stdout.reconfigure(encoding='utf-8')

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
DEVICE_ID = "f35c3099"

def run_adb(args):
    cmd = [ADB, "-s", DEVICE_ID] + args
    res = subprocess.run(cmd, capture_output=True)
    return res.stdout.decode('utf-8', errors='ignore')

def enter_text(field_x, field_y, text):
    print(f"Tapping field at ({field_x}, {field_y})...")
    run_adb(["shell", "input", "tap", str(field_x), str(field_y)])
    time.sleep(1)
    
    print("Clearing field...")
    # Move to end, then delete characters
    keyevents = ["123"] + ["67"] * 30
    run_adb(["shell", "input", "keyevent"] + keyevents)
    time.sleep(1)
    
    print(f"Typing: {text}")
    escaped = text.replace(" ", "%s")
    run_adb(["shell", "input", "text", escaped])
    time.sleep(1)

def main():
    # 1. Tap the "thunderbolt" avatar emoji
    # Bounds: [497,761][688,926]
    # Center: (592, 843)
    print("Tapping thunderbolt avatar emoji at (592, 843)...")
    run_adb(["shell", "input", "tap", "592", "843"])
    time.sleep(1.5)
    
    # 2. Enter Full Name
    # Bounds: [114,1223][966,1388] -> Center: (540, 1305)
    enter_text(540, 1305, "CricUp Admin")
    
    # 3. Enter Bio
    # Bounds: [114,1641][966,2097] -> Center: (540, 1869)
    enter_text(540, 1869, "Keep scoring matches!")
    
    # Dismiss keyboard if shown
    print("Dismissing keyboard...")
    run_adb(["shell", "input", "keyevent", "4"])
    time.sleep(1.5)
    
    # 4. Tap SAVE CHANGES
    # Bounds: [55,2239][1025,2318] -> Center: (540, 2278)
    print("Tapping 'SAVE CHANGES' button at (540, 2278)...")
    run_adb(["shell", "input", "tap", "540", "2278"])
    time.sleep(6)
    
    # 5. Capture screenshot and layout dump to verify success
    print("Capturing post-save state...")
    run_adb(["shell", "screencap", "-p", "/sdcard/screen.png"])
    run_adb(["pull", "/sdcard/screen.png", "C:/Users/praja/.gemini/antigravity-ide/brain/cf74d05a-9d09-4a85-82f1-b3d1bd0d2185/current_screen_after_edit_save.png"])
    run_adb(["shell", "uiautomator", "dump", "/sdcard/window_dump.xml"])
    run_adb(["pull", "/sdcard/window_dump.xml", "C:/Users/praja/.gemini/antigravity-ide/brain/cf74d05a-9d09-4a85-82f1-b3d1bd0d2185/window_dump_after_edit_save.xml"])
    print("Done!")

if __name__ == "__main__":
    main()
