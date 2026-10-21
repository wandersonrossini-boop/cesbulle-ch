import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

sub = content[:4000]
print(re.findall(r'\.container\s*{[^}]*}', sub))
