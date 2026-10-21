import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<main class="app-main">')
end = content.find('<!-- === TAB 4')
sub = content[start:end]

lines = sub.split('\n')
depth = 0
for line in lines:
    opens = line.count('<main') + line.count('<div')
    closes = line.count('</main') + line.count('</div')
    depth += opens - closes

print("Depth right before TAB 4:", depth)
