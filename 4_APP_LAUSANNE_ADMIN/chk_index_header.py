with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "02:05" in line or "CME LAUSANNE" in line or "fa-bars" in line:
        print(f"Line {i+1}: {line.strip()}")
