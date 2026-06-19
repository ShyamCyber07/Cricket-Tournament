import os

print(".github/workflows exists:", os.path.exists(".github/workflows"))
if os.path.exists(".github/workflows"):
    print("Files:", os.listdir(".github/workflows"))
