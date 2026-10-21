import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="tab-services"')
end = content.find('<!-- External Logic')
sub = content[start:end]
lines = sub.split('\n')
depth = 0
for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    depth += opens - closes

print("Depth from tab-services to end:", depth)
