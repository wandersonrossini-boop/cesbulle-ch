with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(1200, 1285):
    if "function" in lines[i]:
        print(f"{i+1}: {lines[i].strip()}")
