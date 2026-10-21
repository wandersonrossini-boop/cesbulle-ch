import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
for i in range(max(0, 360), min(len(lines), 400)):
    print(f"{i+1}: {lines[i].encode('ascii', 'ignore').decode('ascii')}")
