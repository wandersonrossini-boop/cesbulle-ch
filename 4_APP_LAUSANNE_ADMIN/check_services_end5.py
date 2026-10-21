import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('submitServiceInterest')
sub = content[start-100:start+1000]
print(sub)
