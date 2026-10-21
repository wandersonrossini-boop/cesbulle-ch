with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(610, 625):
    try:
        print(f"{i+1}: {lines[i].strip()}")
    except:
        pass
