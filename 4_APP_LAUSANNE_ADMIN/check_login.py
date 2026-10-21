import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="view-login-form"')
if start == -1:
    start = content.find('login')
sub = content[start-200:start+2500]
print(sub.encode('ascii', 'ignore').decode('ascii'))
