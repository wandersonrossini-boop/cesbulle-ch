import re
with open('admin.html', 'r', encoding='utf-8') as f:
    html = f.read()
matches = re.findall(r'<h[1-3].*?>.*?</h[1-3]>|<iframe.*?src=".*?".*?>|<div.*?class=".*?nav-link.*?".*?>', html, re.IGNORECASE)
for m in matches:
    print(m.strip()[:150])
