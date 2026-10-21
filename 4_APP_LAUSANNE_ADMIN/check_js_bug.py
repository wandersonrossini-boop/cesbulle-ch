import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function renderEscalaContent')
sub = content[start-200:start+2500]
print(sub.encode('ascii', 'ignore').decode('ascii'))
