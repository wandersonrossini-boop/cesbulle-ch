import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

sub = content[18042-200:18042+1500]
print(sub)
