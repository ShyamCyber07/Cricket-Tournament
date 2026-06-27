import os

log_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\5f3d97b0-9e18-49db-a8ec-cbb983c80bb6\.system_generated\tasks\task-2050.log"
print(f"Checking path: {log_path}")
if os.path.exists(log_path):
    print("Log file exists! Reading content:")
    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
        print(f.read())
else:
    print("Log file does not exist.")
