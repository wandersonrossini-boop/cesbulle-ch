import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

print("Events:")
start = content.find('id="tab-events"')
print(content[start:start+100])

print("\nServices:")
start = content.find('id="tab-services"')
print(content[start:start+150])
