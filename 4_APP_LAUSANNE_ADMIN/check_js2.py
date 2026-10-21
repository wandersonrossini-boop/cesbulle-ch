import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

sub = content[-1000:]
print(sub.encode('ascii', 'ignore').decode('ascii'))
