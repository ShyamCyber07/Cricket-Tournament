log_path = r"C:\Users\praja\.gemini\antigravity-ide\brain\55c5d66f-9b9f-4f87-92f4-55dfa487d321\.system_generated\tasks\task-1309.log"

with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines[-35:]:
    print(line.strip())
