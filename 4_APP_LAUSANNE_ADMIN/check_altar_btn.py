import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function updateMobileEscalaButton')
sub = content[start:start+1200]
print(sub.encode('ascii', 'ignore').decode('ascii'))
