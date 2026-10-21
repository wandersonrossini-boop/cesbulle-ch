import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

matches = [m.start() for m in re.finditer('class="mobile-header"', content)]
print(matches)
