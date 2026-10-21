with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(2190, 2220):
    print(f"{i+1}: {lines[i].strip()}")
