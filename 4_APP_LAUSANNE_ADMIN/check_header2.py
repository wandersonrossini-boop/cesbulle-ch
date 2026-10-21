import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('class="mobile-header"')
sub = content[start:start+400]
print(sub.encode('ascii', 'ignore').decode('ascii'))
