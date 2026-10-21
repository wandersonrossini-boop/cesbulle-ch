import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('selection-card-kid')
sub = content[start-500:start+1000]
print(sub)
