with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "function logout" in line or "onAuthLogout" in line:
        for j in range(i-2, i+15):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
