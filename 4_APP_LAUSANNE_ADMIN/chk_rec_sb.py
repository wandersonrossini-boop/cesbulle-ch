with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "class=\"pc-sidebar\"" in line:
        for j in range(i, i+30):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
