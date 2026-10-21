with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function loadAtaDigitalCompleta()" in line:
        for j in range(i, i+35):
            print(lines[j].strip())
        break
