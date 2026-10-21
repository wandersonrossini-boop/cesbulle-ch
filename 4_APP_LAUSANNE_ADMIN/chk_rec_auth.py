with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "AuthManager" in line or "gabinete" in line:
        print(f"{i+1}: {line.strip()}")
