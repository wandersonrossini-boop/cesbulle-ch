with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(330, 370):
    print(f"{i+1}: {lines[i].rstrip()}")
