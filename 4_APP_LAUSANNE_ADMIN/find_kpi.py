with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "async function loadKPIs()" in line:
        print(f"Line {i+1}")
