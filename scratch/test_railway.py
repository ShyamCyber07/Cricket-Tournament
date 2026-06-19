import subprocess
import shutil

print("Railway CLI exists:", shutil.which("railway"))
if shutil.which("railway"):
    res = subprocess.run(["railway", "status"], capture_output=True, text=True)
    print("Status stdout:")
    print(res.stdout)
    print("Status stderr:")
    print(res.stderr)
