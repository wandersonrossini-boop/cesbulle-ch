with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "lideres-table-body" in line and "getElementById" in line:
        for j in range(i-5, i+25):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
