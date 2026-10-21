import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

matches = re.findall(r'color\s*:\s*#[a-zA-Z0-9]{3,6}', content)
print(set(matches))
