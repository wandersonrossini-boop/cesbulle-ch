with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "submitVisitor()" in line and "<button" in line:
        for j in range(i-2, i+10):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
