with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(740, 755):
    try:
        print(f"{i+1}: {lines[i].strip()}")
    except:
        pass
