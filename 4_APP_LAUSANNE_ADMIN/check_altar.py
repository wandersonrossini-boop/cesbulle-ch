import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

print("ESCALA found:", content.find('ESCALA') != -1)
print("VISITANTES found:", content.find('VISITANTES') != -1)
