import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function logout')
print(content[start:start+200].encode('ascii', 'ignore').decode('ascii'))
