import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('@media (max-width: 768px)')
sub = content[start:start+1000]
print(sub.encode('ascii', 'ignore').decode('ascii'))
