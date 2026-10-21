import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

matches = [m.start() for m in re.finditer('#999', content)]
for m in matches:
    print(content[m-50:m+50])
