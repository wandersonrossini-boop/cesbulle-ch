import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('latest-visitors-list')
print(content[start-300:start+200])
