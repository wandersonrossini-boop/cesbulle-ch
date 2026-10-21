import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('ENVIAR FICHA</button>')
end = content.find('<!-- === TAB 4')
sub = content[start:end]
lines = sub.split('\n')
for i, line in enumerate(lines[:30]):
    print(line)
