import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('LATEST ENTRIES MODULE')
end = content.find('<!-- 4 ACESSOS INFERIORES')
print(content[start:end])
