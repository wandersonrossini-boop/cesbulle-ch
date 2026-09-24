with open("recepcao_v2.html", "r", encoding="utf-8") as f:
    html = f.read()

import re
html = re.sub(r'<div class="acolhedor-bar"[^>]*>.*?</div>', '', html, flags=re.DOTALL)

with open("recepcao_v2.html", "w", encoding="utf-8") as f:
    f.write(html)
print("Acolhedor container deleted")
