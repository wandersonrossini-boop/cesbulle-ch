import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="pin-screen"')
sub = content[start:start+1200]
print(sub.encode('ascii', 'ignore').decode('ascii'))
