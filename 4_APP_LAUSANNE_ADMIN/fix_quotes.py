import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("window.parent.postMessage(\\'go_home\\', \\'*\\');", "window.parent.postMessage('go_home', '*');")

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Quotes fixed")
