import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

print("Occurrences of #1a1a1a:", content.find('#1a1a1a'))
print("Occurrences of #666:", content.find('#666'))
print("Occurrences of #64748b:", content.find('#64748b'))
