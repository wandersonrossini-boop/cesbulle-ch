with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function loadAtaDigitalCompleta()" in line:
        for j in range(i+15, i+40):
            try:
                print(lines[j].strip())
            except:
                pass
        break
