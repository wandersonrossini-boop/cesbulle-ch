with open("recepcao_v2.html", "r", encoding="utf-8") as f:
    html = f.read()

import re
html = re.sub(r'<i\s+class="[^"]*"\s*[^>]*>(?:</i>)?', '', html)
html = html.replace('</i>', '')

with open("recepcao_v2.html", "w", encoding="utf-8") as f:
    f.write(html)
