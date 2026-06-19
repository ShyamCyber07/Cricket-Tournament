import os

def main():
    kw = "role"
    for root, dirs, files in os.walk("frontend"):
        for file in files:
            if file.endswith(".dart") and "dashboard" in root:
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    for line_num, line in enumerate(f, 1):
                        if kw in line:
                            print(f"{path}:{line_num}: {line.strip()}")

if __name__ == "__main__":
    main()
