import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('iframe.src =')
if start == -1:
    start = content.find('.src =')
sub = content[start-100:start+200]
print(sub.encode('ascii', 'ignore').decode('ascii'))
