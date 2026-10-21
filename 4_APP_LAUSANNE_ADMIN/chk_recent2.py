with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "dashboard-recentes-cultos" in line:
        for j in range(i-2, i+3):
            print(lines[j].strip())
