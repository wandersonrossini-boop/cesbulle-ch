import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('END TAB CHECKIN (Merged)')
end = content.find('<!-- === TAB 4')
sub = content[start:end]
lines = sub.split('\n')

for i, line in enumerate(lines):
    opens = line.count('<div')
    closes = line.count('</div')
    if closes > opens:
        print(f"Line {i} has more closes: {line.strip()}")
