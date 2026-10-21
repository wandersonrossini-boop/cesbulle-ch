import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<header')
if start == -1:
    start = content.find('header')
sub = content[start-100:start+1500]
print(sub.encode('ascii', 'ignore').decode('ascii'))
