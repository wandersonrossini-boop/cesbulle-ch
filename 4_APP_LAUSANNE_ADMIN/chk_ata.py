with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function loadAtaDigitalFeed" in line:
        for j in range(i, i+30):
            print(lines[j].rstrip())
        break
