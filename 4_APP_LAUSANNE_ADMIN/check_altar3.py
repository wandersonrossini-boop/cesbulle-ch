import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
for i in range(max(0, 185 - 20), min(len(lines), 185 + 40)):
    print(f"{i}: {lines[i].encode('ascii', 'ignore').decode('ascii')}")
