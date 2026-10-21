import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="col-e"')
sub = content[start-100:start+400]
print(sub.encode('ascii', 'ignore').decode('ascii'))
