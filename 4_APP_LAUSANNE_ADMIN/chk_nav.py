with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "nav-item" in line and "nav-" in line:
        print(line.strip())
