import re

with open('kids.html', 'r', encoding='utf-8') as f:
    content = f.read()

print("File size:", len(content))
