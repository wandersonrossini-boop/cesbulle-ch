with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function loadKPIs()" in line:
        for j in range(i, i+5):
            print(lines[j].strip())
        break
