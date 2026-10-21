with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "function loadDiretrizesPage" in line:
        for j in range(i, i+50):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
