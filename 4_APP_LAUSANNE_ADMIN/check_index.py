import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('onAuthSuccess')
sub = content[start-100:start+1000]
print(sub)
