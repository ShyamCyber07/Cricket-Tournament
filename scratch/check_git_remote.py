import subprocess

res = subprocess.run(["git", "remote", "-v"], capture_output=True, text=True)
print("Git Remotes:")
print(res.stdout)

res2 = subprocess.run(["git", "status"], capture_output=True, text=True)
print("\nGit Status:")
print(res2.stdout)
