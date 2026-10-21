import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function openNovaEscala')
sub = content[start:start+1000]
print(sub.encode('ascii', 'ignore').decode('ascii'))
