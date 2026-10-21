import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function showLoginView')
sub = content[start:start+500]
print(sub.encode('ascii', 'ignore').decode('ascii'))
