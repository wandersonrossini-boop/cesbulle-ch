with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "sidebar-header" in line:
        for j in range(i-2, i+20):
            print(lines[j].rstrip())
        break
