import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<head>')
sub = content[start:start+1000]
print(sub.encode('ascii', 'ignore').decode('ascii'))
