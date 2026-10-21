import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()
    
start = content.find('id="tab-live"')
print(content[start-50:start+100])
