import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find("alert('Enviada com")
if start == -1:
    start = content.find("alert(")

if start != -1:
    sub = content[start-200:start+200]
    print(sub.encode('ascii', 'ignore').decode('ascii'))
else:
    print("alert not found")
