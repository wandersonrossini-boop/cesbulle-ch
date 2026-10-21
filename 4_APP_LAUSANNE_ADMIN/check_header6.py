import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('INÍCIO</div>')
if start == -1:
    start = content.find('IN')
sub = content[start-100:start+300]
print(repr(sub))
