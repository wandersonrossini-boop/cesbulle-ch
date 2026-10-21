import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="btn-e"')
if start == -1:
    print("id='btn-e' NOT FOUND in HTML!")
else:
    sub = content[start-100:start+200]
    print(sub.encode('ascii', 'ignore').decode('ascii'))
