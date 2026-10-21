import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('submitFullMembershipWizard')
end = content.find('<style>')
sub = content[start:end]
print(sub)
