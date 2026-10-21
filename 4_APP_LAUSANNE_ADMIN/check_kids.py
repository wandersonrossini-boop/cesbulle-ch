import re

with open('kids.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('Identificação')
if start == -1:
    start = content.find('IDENTIFICA')
sub = content[start-200:start+200]
print(sub.encode('ascii', 'ignore').decode('ascii'))
