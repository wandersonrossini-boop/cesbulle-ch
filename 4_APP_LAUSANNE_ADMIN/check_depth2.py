import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<!-- === TAB 3')
end = content.find('<!-- === TAB 4')
substring = content[start:end]

lines = substring.split('\n')
for i in range(480, 495):
    if i < len(lines):
        print(f"{i}: {lines[i]}")
