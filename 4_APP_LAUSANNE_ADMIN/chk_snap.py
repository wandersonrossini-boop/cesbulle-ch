with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "if(allScales.length === 0)" in line:
        for j in range(i-2, i+5):
            print(lines[j].strip())
        break
