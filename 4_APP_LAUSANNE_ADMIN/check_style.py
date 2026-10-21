import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

sub = content[16000:20000]
print(sub.find('<style>'))
