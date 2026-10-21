with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

import re
navs = re.findall(r'<div class="sidebar-nav">.*?</div>', content, re.DOTALL)
if navs:
    print(navs[0])
else:
    print("Not found")
