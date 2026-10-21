import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('ultimas-entradas-container')
sub = content[start-500:start+100]
print(sub)
