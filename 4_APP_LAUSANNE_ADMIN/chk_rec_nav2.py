with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "class=\"sidebar-nav\"" in line:
        for j in range(i, i+15):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
