import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

print("openEscalaMobile found:", content.find('openEscalaMobile') != -1)
