import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('.container')
sub = content[start-50:start+300]
print(sub.encode('ascii', 'ignore').decode('ascii'))
