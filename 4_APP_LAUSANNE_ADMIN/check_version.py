import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('const version =')
if start == -1:
    start = content.find('let version')
if start == -1:
    start = content.find('var version')
if start == -1:
    print("Version not found in index.html")
else:
    sub = content[start-10:start+100]
    print(sub.encode('ascii', 'ignore').decode('ascii'))
