import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

matches = [m.start() for m in re.finditer('MOBILE RESPONSIVENESS', content)]
print(matches)
