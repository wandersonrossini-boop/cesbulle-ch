with open('js/auth-manager.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(155, 175):
    try:
        print(f"{i+1}: {lines[i].rstrip()}")
    except:
        pass
