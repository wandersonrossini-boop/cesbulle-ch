import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<!-- === TAB 4')
end = content.find('<!-- === TAB 5') if '<!-- === TAB 5' in content else content.find('<!-- LOGIN MODAL')
print(content[start:start+1500])
