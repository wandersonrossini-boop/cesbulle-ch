with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()
import re
navs = re.findall(r'<nav.*?>.*?</nav>', content, re.DOTALL)
for n in navs:
    print(n)
