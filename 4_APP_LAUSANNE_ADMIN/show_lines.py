with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i in range(100, 115):
    print(f"{i+1}: {lines[i].strip()}")
