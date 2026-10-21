import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('ESCALA')
sub = content[start-200:start+2000]
print(sub.encode('ascii', 'ignore').decode('ascii'))
