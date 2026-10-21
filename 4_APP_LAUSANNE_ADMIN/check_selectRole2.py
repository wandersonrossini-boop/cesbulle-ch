import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function selectRole(')
sub = content[start:start+1800]
print(sub.encode('ascii', 'ignore').decode('ascii'))
