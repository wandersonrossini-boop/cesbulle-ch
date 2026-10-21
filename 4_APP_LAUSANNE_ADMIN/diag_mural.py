import re
with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    html = f.read()
match = re.search(r'(<div[^>]*?id="mode-mural"[^>]*?>.*?</div>\s*<!-- MODE ONLINE)', html, re.DOTALL | re.IGNORECASE)
if match:
    print(match.group(1)[:500])
else:
    print("Not found exactly like that, let's just find mode-mural")
    match2 = re.search(r'(<div[^>]*?id="mode-mural"[^>]*?>.{0,800})', html, re.DOTALL | re.IGNORECASE)
    if match2: print(match2.group(1))
