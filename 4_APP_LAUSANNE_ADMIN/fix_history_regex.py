import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r"// Concluidas.*?\}\);", re.DOTALL)
content = re.sub(pattern, "", content)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed Concluidas block with regex")
