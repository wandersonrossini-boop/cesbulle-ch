import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="tab-services"')
sub = content[start:start+4000]
lines = sub.split('\n')
for i, line in enumerate(lines[-30:]):
    print(line)
