import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('END TAB CHECKIN (Merged)')
end = content.find('<!-- === TAB 4')
sub = content[start:end]
lines = sub.split('\n')

depth = 0
for line in lines:
    opens = line.count('<div')
    closes = line.count('</div')
    depth += opens - closes

print("Depth change between end of tab-checkin and tab 4:", depth)
