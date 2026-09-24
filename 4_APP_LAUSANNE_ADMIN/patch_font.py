import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('--border-dark: #1E293B !important;', '--border-dark: #1E293B !important;\n            --font-serif: \'Playfair Display\', serif !important;')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Font serif patched.")
