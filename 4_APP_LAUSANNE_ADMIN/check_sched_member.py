import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="sched-mode-member"')
end = content.find('<!-- === TAB 4')
sub = content[start:end]
lines = sub.split('\n')

for i, line in enumerate(lines[:30]):
    print(f"{i}: {line}")
