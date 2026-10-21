with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "id=\"page-diretrizes\"" in line:
        for j in range(i, i+25):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
