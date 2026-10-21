with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "vis-name" in line and "value = ''" in line:
        for j in range(i-5, i+15):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
