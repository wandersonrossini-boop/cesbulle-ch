import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<div class="container"')
end = content.find('<!-- === TAB 4')

sub = content[start:end]
lines = sub.split('\n')

for i in range(365, 375):
    print(f"{i}: {lines[i]}")
