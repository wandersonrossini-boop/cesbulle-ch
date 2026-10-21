with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "function selectRole" in line or "function load" in line or "iframe" in line.lower():
        for j in range(i, i+15):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
