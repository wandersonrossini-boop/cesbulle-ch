import re
with open('admin.html', 'r', encoding='utf-8') as f:
    html = f.read()
matches = re.findall(r'onclick="[^"]*?(?:tab|switch|section|pane)[^"]*?"[^>]*?>(.*?)<', html, re.IGNORECASE)
for m in matches:
    print(m.strip())
