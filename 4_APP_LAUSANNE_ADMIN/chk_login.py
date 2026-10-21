with open('js/auth-manager.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async login" in line:
        for j in range(i, i+30):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
