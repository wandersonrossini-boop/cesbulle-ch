import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('70.3.87', '70.3.88')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Bumped global version to 70.3.88")
