with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "sidebar-brand" in line:
        for j in range(i-2, i+5):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
