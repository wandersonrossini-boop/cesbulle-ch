with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(1470, 1495):
    print(f"{i+1}: {lines[i].strip()}")
