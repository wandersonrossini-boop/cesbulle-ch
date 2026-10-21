import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

matches = [m.start() for m in re.finditer('div.className = \'selection-card-kid\';', content)]
print("Found matches at:", matches)

if len(matches) >= 3:
    start = matches[2]
    sub = content[start:start+1500]
    print(sub)
