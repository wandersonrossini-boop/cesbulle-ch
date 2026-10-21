import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('.mobile-header {')
# find all occurrences of .mobile-header in CSS
matches = re.finditer(r'\.mobile-header[^{]*\{[^}]*\}', content)
for m in matches:
    print(m.group(0))
