import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. Remove the CSS rule for #tab-checkin > .segmented-control { display: flex !important; }
html = re.sub(r'#tab-checkin > \.segmented-control\s*{[^}]*display:\s*flex\s*!important;[^}]*}', '/* CSS rule removed */', html, flags=re.DOTALL | re.IGNORECASE)

# 2. Also remove any other display related rules for it if any. Let's just remove the main one.
# It seems there are multiple. Let's remove ALL '#tab-checkin > .segmented-control' blocks from CSS just to be safe, because they are no longer needed.
# Actually, the user just said: "remover a regra CSS específica que força .segmented-control dentro de #tab-checkin".
# I'll just remove the specific one causing the issue to be safe and minimalistic.

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(html)
