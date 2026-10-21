with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "function switchPage" in line:
        for j in range(i+15, i+25):
            print(lines[j].rstrip())
        break
