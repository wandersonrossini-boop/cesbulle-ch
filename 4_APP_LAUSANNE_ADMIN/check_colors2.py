import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

matches = [m.start() for m in re.finditer('64748b', content)]
for m in matches:
    print(content[max(0, m-50):min(len(content), m+50)])
