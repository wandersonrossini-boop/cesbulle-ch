with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

lines.pop(346)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.writelines(lines)
