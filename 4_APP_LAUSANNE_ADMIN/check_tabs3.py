import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<!-- === TAB 3')
end = content.find('<!-- === TAB 4')
substring = content[start:end]

script_start = substring.find('<script>')
print("Lines around script start:")
print(substring[script_start-200:script_start+200])
