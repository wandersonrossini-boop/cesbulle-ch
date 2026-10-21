import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function selectRole')
print(content[start:start+400].encode('ascii', 'ignore').decode('ascii'))
