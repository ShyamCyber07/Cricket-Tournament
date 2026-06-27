import os

def search():
    paths = [
        r"C:\src",
        r"C:\Users\praja\AppData\Local",
        r"C:\Users\praja\flutter",
        r"C:\flutter",
        r"C:\Program Files"
    ]
    
    print("Searching for flutter.bat...")
    for base_path in paths:
        if not os.path.exists(base_path):
            continue
        print(f"Checking {base_path}...")
        for root, dirs, files in os.walk(base_path):
            # Avoid traversing deep package/cache/build/node_modules/etc folders
            # modify dirs in place to prune traversal
            dirs[:] = [d for d in dirs if d.lower() not in ["node_modules", ".git", ".gradle", "build", "cache", "pub-cache", "android", "ios", "windows", "macos", "linux", "web"]]
            if "flutter.bat" in files:
                full_path = os.path.join(root, "flutter.bat")
                print(f"FOUND: {full_path}")
                return

if __name__ == "__main__":
    search()
