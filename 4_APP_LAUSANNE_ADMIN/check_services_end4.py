import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('ministry-grid')
sub = content[start+2000:start+3000]
print(sub)
