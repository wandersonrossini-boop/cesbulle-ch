with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "<th>E-mail</th>" in line or "<th>E-MAIL</th>" in line:
        print(f"Error: E-mail column still exists at line {i+1}: {line.strip()}")
    if "lideres-table-body" in line:
        for j in range(i-6, i+5):
            print(lines[j].strip())
        break
