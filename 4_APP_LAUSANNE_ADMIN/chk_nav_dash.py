with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "nav-dashboard" in line:
        for j in range(i-2, i+15):
            print(lines[j].rstrip())
        break
