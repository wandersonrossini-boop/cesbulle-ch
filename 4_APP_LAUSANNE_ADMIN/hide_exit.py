import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Add display: none !important to exit-btn on mobile
content = content.replace('.pc-only { display: block; }', '.pc-only { display: block; }\n        @media (max-width: 900px) { .exit-btn { display: none !important; } }')

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Exit btn hidden on mobile")
