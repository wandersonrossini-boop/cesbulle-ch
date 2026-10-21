import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('id="wizard-step-4"')
end = content.find('id="tab-services"')
sub = content[start:end]
lines = sub.split('\n')
for i in range(0, min(30, len(lines))):
    print(lines[i].strip())
print("...")
for i in range(max(0, len(lines)-30), len(lines)):
    print(lines[i].strip())
