with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "dashboard-recentes-cultos" in line:
        print("Found recent:", line.strip())
