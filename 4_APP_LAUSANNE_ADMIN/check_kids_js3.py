import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

matches = [m.start() for m in re.finditer('selection-card-kid', content)]
for m in matches:
    print(content[m-200:m+600])
    print("---------------------------------")
