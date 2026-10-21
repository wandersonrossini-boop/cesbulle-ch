import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# find v=70.3.85 and replace with v=70.3.86
content = content.replace('70.3.85', '70.3.86')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Version bumped to 70.3.86")
