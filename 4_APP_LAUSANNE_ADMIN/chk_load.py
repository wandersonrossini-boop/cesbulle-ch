with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "function loadEscalas()" in line:
        for j in range(i, min(i+40, len(lines))):
            print(lines[j].strip())
        break
