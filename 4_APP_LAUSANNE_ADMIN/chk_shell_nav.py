with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "nav-" in line or "module-item" in line:
        print(f"Line {i+1}: {line.strip()}")
