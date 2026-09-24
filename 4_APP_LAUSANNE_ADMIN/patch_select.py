import re
with open('recepcao_v2.html', 'r', encoding='utf-8') as f: content = f.read()
content = content.replace('color: #334155;', 'color: var(--text-light);')
with open('recepcao_v2.html', 'w', encoding='utf-8') as f: f.write(content)
