with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if ">Sair<" in line or ">Sair " in line or " Sair<" in line:
        print(f"Line {i+1}: {line.strip()}")
