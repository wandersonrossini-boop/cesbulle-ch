import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('color:#64748b', 'color:var(--text-muted)')

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed #64748b")
