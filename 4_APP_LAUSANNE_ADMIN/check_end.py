with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(len(lines)-20, len(lines)):
    print(f"{i+1}: {lines[i].strip()}")
