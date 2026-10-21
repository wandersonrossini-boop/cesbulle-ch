import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace hardcoded dark text colors with CSS variables for dark theme
content = content.replace('color:#1a1a1a;', 'color:var(--text-light);')
content = content.replace('color:#666;', 'color:var(--text-muted);')

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed colors in js/reception_kids_logic.js")
