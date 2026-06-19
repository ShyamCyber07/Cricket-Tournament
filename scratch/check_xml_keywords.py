with open("curr.xml", "r", encoding="utf-8", errors="ignore") as f:
    xml_content = f.read()

keywords = ["Score", "Setup", "Ready", "Match", "Teams", "Tournaments", "Players"]
for kw in keywords:
    print(f"Keyword '{kw}':", kw.lower() in xml_content.lower())
