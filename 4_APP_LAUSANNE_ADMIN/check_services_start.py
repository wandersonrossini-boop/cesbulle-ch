import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="tab-services"')
sub = content[start:]
lines = sub.split('\n')
for line in lines[0:20]:
    print(line)
