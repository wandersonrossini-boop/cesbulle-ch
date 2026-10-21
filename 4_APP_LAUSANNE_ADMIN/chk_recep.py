with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "nav-item" in line or "sidebar" in line:
        print(f"Line {i+1}: {line.strip()}")
