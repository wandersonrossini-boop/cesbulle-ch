import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('Nova Crian')
sub = content[start-200:start+200]
print(sub)
