import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('color:#1e293b;', 'color:var(--text-light);')
content = content.replace('color:#64748b;', 'color:var(--text-muted);')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed more colors in recepcao_v2.html")
