import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="tab-checkin"')
end = content.find('id="tab-live"')
sub = content[start:end]

matches = [m.start() for m in re.finditer('#1e293b|#64748b|#94a3b8', sub)]
for m in matches:
    print(sub[max(0, m-80):min(len(sub), m+80)])
    print("---------------------------------")
