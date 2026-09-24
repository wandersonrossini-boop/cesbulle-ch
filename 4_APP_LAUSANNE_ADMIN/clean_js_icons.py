with open("js/reception_kids_logic.js", "r", encoding="utf-8") as f:
    js = f.read()

import re
js = re.sub(r'<i\b[^>]*>(?:</i>)?', '', js)
js = js.replace('</i>', '')

# Replace any gold color references in reception_kids_logic.js
js = js.replace('#d4af37', '#0f172a')
js = js.replace('var(--gold-primary)', '#0f172a')

with open("js/reception_kids_logic.js", "w", encoding="utf-8") as f:
    f.write(js)

print("JS logic cleaned of icons and gold")
