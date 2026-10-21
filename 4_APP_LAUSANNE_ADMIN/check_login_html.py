import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<div id="view-login">')
if start == -1:
    start = content.find('view-login')
sub = content[start-50:start+2500]
print(sub.encode('ascii', 'ignore').decode('ascii'))
