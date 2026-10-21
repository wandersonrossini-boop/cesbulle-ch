import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('13:08')
if start == -1:
    start = content.find('CULTO AO VIVO')
sub = content[start-200:start+2000]
print(sub.encode('ascii', 'ignore').decode('ascii'))
