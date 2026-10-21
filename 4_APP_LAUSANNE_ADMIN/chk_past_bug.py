with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "PASTORAL" in line and "op-title" in line:
        for j in range(i-5, i+5):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
