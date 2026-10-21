with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if i >= 1279 and i <= 1285:
        print(f"{i+1}: {line.strip()}")
