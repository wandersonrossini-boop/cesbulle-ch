import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="sched-mode-member"')
end = content.find('<!-- === TAB 4')
sub = content[start:end]

lines = sub.split('\n')
depth = 0
for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    depth += opens - closes
    if depth < 0:
        print(f"Depth hit {depth} at {i}: {line.strip()}")
