import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('Onde voce gostaria de servir')
sub = content[start-100:start+2000]
print(sub)
