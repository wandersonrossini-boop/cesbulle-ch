import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('class="pc-visitor-grid"')
end = content.find('<!-- 4 ACESSOS INFERIORES')
sub = content[start:end]

lines = sub.split('\n')
for i, line in enumerate(lines[-20:]):
    print(line)
