import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('border:1px solid #eee; border-radius:12px; padding:12px; background:#fbfbfb;', 'border:1px solid var(--border-dark); border-radius:12px; padding:12px; background:var(--navy-main);')
content = content.replace('color:var(--gold)', 'color:var(--text-light)')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Details patched.")
