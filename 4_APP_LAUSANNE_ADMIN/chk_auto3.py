with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "localStorage.getItem" in line and "current_module" in line:
        for j in range(i-5, i+20):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
