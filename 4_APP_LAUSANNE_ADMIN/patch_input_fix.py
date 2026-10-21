import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''            color: var(--text-light) !important;
            box-sizing: border-box !important;
            width: 100%;
            max-width: 100% !important;
        }'''

replacement = '''            color: var(--text-light) !important;
            box-sizing: border-box !important;
            max-width: 100% !important;
        }'''

content = content.replace(target, replacement)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed width: 100% from inputs.")
