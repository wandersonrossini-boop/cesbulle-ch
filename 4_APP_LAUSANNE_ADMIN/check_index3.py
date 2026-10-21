import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('onAuthSuccess')
print(content[start-50:start+1000].encode('ascii', 'ignore').decode('ascii'))
