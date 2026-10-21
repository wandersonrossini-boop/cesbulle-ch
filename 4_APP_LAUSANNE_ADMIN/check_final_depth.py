import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
depth = 0
for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    depth += opens - closes

print("Final depth:", depth)
