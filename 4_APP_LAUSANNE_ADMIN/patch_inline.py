import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('color:#0f172a;', 'color:var(--text-light);')
content = content.replace('color: #0f172a;', 'color: var(--text-light);')
content = content.replace('background:#ffffff;', 'background:var(--navy-main);')
content = content.replace('background: #ffffff;', 'background: var(--navy-main);')
content = content.replace('border:1px solid #cbd5e1;', 'border: 1px solid var(--border-dark);')
content = content.replace('border: 1px solid #cbd5e1;', 'border: 1px solid var(--border-dark);')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Inline colors patched.")
