import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('const moduleFiles')
sub = content[start:start+1000]
print(sub.encode('ascii', 'ignore').decode('ascii'))
