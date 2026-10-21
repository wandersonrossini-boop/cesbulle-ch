with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(1905, 1930):
    try:
        print(f"{i+1}: {lines[i].rstrip()}")
    except:
        pass
