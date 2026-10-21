with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function excluirEscala" in line:
        for j in range(i-5, i+2):
            print(lines[j].strip())
        break
