import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<div class="four-cards-row">')
end = content.find('id="tab-live"')
print(content[start:end])
