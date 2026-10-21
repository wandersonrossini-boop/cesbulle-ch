import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<div class="container"')
end = content.find('<!-- === TAB 4')

sub = content[start:end]
lines = sub.split('\n')

depth = 0
for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    
    if depth == 1 and opens > 0:
        print(f"Direct child at {i}: {line.strip()}")
    
    depth += opens - closes
