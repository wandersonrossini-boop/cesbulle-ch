with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(275, 290):
    try:
        print(f"{i+1}: {lines[i].rstrip()}")
    except:
        pass
