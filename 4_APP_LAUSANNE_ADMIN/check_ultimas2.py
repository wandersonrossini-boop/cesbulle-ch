import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('LATEST ENTRIES MODULE')
sub = content[0:start]

print("Is it inside tab-checkin?", sub.rfind('<div id="tab-checkin"') > sub.rfind('</div>', 0, sub.rfind('<div id="tab-checkin"')))
