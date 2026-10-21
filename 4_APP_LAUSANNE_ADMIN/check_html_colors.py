import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="tab-checkin"')
end = content.find('id="tab-live"')
sub = content[start:end]

matches = re.findall(r'color\s*:\s*#[a-zA-Z0-9]{3,6}', sub)
print(set(matches))
