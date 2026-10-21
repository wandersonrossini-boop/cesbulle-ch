import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="tab-services"')
end = content.find('<!-- External Logic')
sub = content[start:end]
print(sub[-300:])
