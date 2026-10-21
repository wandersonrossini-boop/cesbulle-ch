import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Hide check-in segmented control
html = re.sub(r'(<!-- SEGMENTED CONTROL -->\s*<div class="segmented-control") style="margin-bottom: 25px;"', r'\1 style="display:none; margin-bottom: 25px;"', html, flags=re.DOTALL | re.IGNORECASE)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(html)
