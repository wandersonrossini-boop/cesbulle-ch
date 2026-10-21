with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if "// Dashboard upcoming and recent filter" in line:
        skip = True
    if skip and "document.getElementById('dashboard-recentes-cultos').innerHTML" in line:
        skip = False
        continue
    if not skip:
        new_lines.append(line)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Safely removed the broken dashboard logic!")
