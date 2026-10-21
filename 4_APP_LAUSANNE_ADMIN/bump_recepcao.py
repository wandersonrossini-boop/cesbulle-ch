import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('reception_kids_logic.js?v=70.3.79', 'reception_kids_logic.js?v=70.3.88')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Bumped reception_kids_logic.js version in recepcao_v2.html")
