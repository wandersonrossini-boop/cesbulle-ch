import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('color:#666;', 'color:var(--text-muted);')
content = content.replace('color: #666;', 'color: var(--text-muted);')
content = content.replace('color:#aaa;', 'color:var(--text-muted);')
content = content.replace('background:#f8fafc;', 'background:var(--navy-main);')
content = content.replace('background: #f8fafc;', 'background: var(--navy-main);')
content = content.replace('border:1px solid #e2e8f0;', 'border:1px solid var(--border-dark);')
content = content.replace('border: 1px solid #e2e8f0;', 'border: 1px solid var(--border-dark);')
content = content.replace('background:#fff;', 'background:var(--navy-card);')
content = content.replace('background: #fff;', 'background: var(--navy-card);')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("More inline colors patched.")
