with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "bottom-nav" in line:
        for j in range(i, i+25):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
