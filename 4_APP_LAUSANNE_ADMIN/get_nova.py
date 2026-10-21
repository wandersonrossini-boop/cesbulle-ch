with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "function openNovaEscala(" in line:
        for j in range(max(0, i-2), min(i+10, len(lines))):
            print(f"{j+1}: {lines[j].strip()}")
        break
