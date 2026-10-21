with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(330, 355):
    try:
        print(f"{i+1}: {lines[i].rstrip()}")
    except:
        pass
