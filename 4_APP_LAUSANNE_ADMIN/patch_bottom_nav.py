import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('.bottom-nav { display: none !important; }', '/* .bottom-nav hidden removed */')
content = content.replace('.bottom-nav {\n            display: none !important;\n        }', '/* bottom nav hidden removed */')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed old bottom-nav display: none")
