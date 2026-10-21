import re
with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()
lines = content.split('\n')
for i in range(max(0, 520), min(len(lines), 550)):
    print(f"{i+1}: {lines[i]}")
