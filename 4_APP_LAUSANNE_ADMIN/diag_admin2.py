import re
with open('admin.html', 'r', encoding='utf-8') as f:
    html = f.read()
# Find sidebar elements
matches = re.findall(r'<a.*?class=".*?sidebar-link.*?>(.*?)</a>|<div.*?class=".*?nav-link.*?>(.*?)</div>|<div.*?class=".*?sidebar-item.*?>(.*?)</div>', html, re.IGNORECASE)
for m in matches:
    print(list(filter(None, m))[0].strip())
