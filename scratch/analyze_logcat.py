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
    lines = logs.splitlines()
    
    print(f"Total logcat lines: {len(lines)}")
    
    requests = []
    responses = []
    errors = []
    
    for line in lines:
        if "[Dio Request]" in line:
            requests.append(line)
        if "[Dio Response]" in line:
            responses.append(line)
        if "error" in line.lower() or "exception" in line.lower() or "failed" in line.lower():
            if "flutter" in line.lower():
                errors.append(line)
                
    print(f"Total Dio Requests: {len(requests)}")
    print(f"Total Dio Responses: {len(responses)}")
    print(f"Total Flutter Errors/Exceptions: {len(errors)}")
    
    print("\nRecent Dio Responses:")
    for r in responses[-20:]:
        print(r)
        
    print("\nRecent Flutter Errors:")
    for e in errors[-20:]:
        print(e)

if __name__ == "__main__":
    main()
