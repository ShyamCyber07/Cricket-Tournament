import subprocess

res = subprocess.run(["git", "diff", "frontend/lib/features/dashboard/screens/dashboard_screen.dart"], capture_output=True, text=True)
print("Git Diff of dashboard_screen.dart:")
print(res.stdout)
