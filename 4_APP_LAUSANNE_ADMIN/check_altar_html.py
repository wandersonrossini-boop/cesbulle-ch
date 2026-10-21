import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="btn-e"')
sub = content[start-100:start+300]
print(sub.encode('ascii', 'ignore').decode('ascii'))

start2 = content.find('id="col-e"')
sub2 = content[start2-100:start2+300]
print("\n---\n" + sub2.encode('ascii', 'ignore').decode('ascii'))
