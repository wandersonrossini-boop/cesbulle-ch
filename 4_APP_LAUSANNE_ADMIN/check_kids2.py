import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function loadAllKidsList')
sub = content[start:start+3000]
print(sub)
