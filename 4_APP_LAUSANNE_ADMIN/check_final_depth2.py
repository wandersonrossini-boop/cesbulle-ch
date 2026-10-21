import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<div class="container"')
sub = content[start:]
lines = sub.split('\n')
depth = 0
for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    depth += opens - closes

print("Depth from container to EOF:", depth)
