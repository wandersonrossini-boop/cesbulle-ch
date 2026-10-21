import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('submitFullMembershipWizard')
end = content.find('<!-- === TAB 4: SERVI')
sub = content[start:end]
lines = sub.split('\n')
for line in lines[:30]:
    print(line.strip())
