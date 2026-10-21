import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('CONFIRMAR INSCRI')
sub = content[start-200:start+1000]
print(sub)
