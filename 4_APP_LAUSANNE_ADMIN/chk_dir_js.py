with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function loadDiretrizesPage()" in line:
        for j in range(i+25, i+45):
            try:
                print(lines[j].rstrip())
            except:
                pass
        break
