import os
os.system('git show HEAD~1:4_APP_LAUSANNE_ADMIN/gabinete.html > old_gabinete.html')
with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "modal-escala" in line:
        for j in range(max(0, i-2), min(i+10, len(lines))):
            print(f"{j+1}: {lines[j].strip()}")
        break
