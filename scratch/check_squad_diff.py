import subprocess

res = subprocess.run(["git", "diff", "frontend/lib/features/matches/screens/squad_selection_screen.dart"], capture_output=True, text=True)
print("Git Diff of squad_selection_screen.dart:")
print(res.stdout)
