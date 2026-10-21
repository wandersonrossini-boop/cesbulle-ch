with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(415, 480):
    try:
        print(f"{i+1}: {lines[i].rstrip()}")
    except:
        pass
