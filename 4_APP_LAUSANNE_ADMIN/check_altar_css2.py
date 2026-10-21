import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# find all media queries
matches = re.finditer(r'@media\s*\([^\{]+\)\s*\{', content)
for m in matches:
    print(content[m.start():m.start()+200].encode('ascii', 'ignore').decode('ascii'))
