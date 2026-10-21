with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "// Dashboard upcoming and recent filter" in line:
        for j in range(max(0, i-2), min(i+40, len(lines))):
            print(f"{j+1}: {lines[j].strip()}")
        break
