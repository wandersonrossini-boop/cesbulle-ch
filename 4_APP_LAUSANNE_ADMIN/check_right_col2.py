import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('RIGHT COLUMN')
end = content.find('LATEST ENTRIES MODULE')
sub = content[start:end]
print(sub)
