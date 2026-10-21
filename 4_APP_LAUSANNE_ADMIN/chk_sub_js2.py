with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "submitVisitor" in line and "function" in line:
        for j in range(i, i+30):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
