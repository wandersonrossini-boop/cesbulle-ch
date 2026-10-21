import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

print("latest-visitors-list in container?", "latest-visitors-list" in content[content.find('<div class="container"'):content.find('<!-- === TAB 3')])
