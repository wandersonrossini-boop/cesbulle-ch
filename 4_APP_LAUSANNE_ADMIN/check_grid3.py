import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.rfind('class="pc-visitor-grid"')
sub = content[start-100:start+200]
print(sub)
