with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(2200, 2300):
    if "script" in lines[i] or "html" in lines[i]:
        print(f"{i+1}: {lines[i].strip()}")
