with open('kids.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "innerHTML =" in line:
        for j in range(i-2, min(i+15, len(lines))):
            print(f"{j+1}: {lines[j]}", end='')
        print("------")
