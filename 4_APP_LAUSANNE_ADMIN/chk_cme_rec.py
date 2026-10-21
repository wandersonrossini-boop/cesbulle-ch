with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "CME LAUSANNE" in line or "CME<br>LAUSANNE" in line or "CME" in line:
        print(f"{i+1}: {line.strip()}")
