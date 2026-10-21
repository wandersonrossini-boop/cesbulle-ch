import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''        @media (max-width: 899px) {
            .app-main {
                padding: 15px 15px !important; /* Reclaim massive 40px double padding */
                overflow-x: hidden !important;
                width: 100% !important;
                box-sizing: border-box !important;
            }'''

replacement = '''        @media (max-width: 899px) {
            .app-main {
                padding: 15px 15px !important; /* Reclaim massive 40px double padding */
                width: 100% !important;
                box-sizing: border-box !important;
            }'''

content = content.replace(target, replacement)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed overflow-x: hidden from .app-main on mobile.")
