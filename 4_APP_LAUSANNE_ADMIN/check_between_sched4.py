import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('submitFullMembershipWizard')
end = content.find('// --- AUTH SYNC v48.14.4 ---')
sub = content[start:end]
lines = sub.split('\n')
for line in lines[-20:]:
    print(line.strip())
