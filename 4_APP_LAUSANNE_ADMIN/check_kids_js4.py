import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('docs.forEach(data => {')
end = content.find('listEl.appendChild(div);', start)
sub = content[start:end+50]
print(sub)
