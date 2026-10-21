import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<!-- === TAB 3')
end = content.find('<!-- === TAB 4')
substring = content[start:end]

lines = substring.split('\n')
div_depth = 0
for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    div_depth += opens - closes
    if div_depth == 0 and closes > 0:
        print(f"Reached depth 0 at line {i}: {line.strip()}")
