import re

with open('kids.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('<div class="header-brand">CME LAUSANNE</div>', '')

with open('kids.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed header-brand from kids.html")
