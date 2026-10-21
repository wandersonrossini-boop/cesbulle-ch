import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('window.loadAllKidsList')
print(content[start:start+4000])
