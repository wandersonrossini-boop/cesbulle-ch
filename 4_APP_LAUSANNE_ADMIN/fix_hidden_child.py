import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the CSS rule
content = content.replace('.mobile-header > div:nth-child(2) { display: none !important; }', '/* .mobile-header > div:nth-child(2) { display: none !important; } removed so INICIO button is visible */')

# Remove the hamburger icon from the flex container
# Currently it is:
# <div style="display: flex; gap: 15px; align-items: center;"><div onclick="window.parent.postMessage('go_home', '*');" style="...">← INÍCIO</div><div style="..." onclick="...">☰</div></div>
# Let's just make it simple: replace the whole 2nd child with just the INÍCIO button.

import re
pattern = re.compile(r'<div style="display: flex; gap: 15px; align-items: center;">\s*<div onclick="window\.parent\.postMessage\(\'go_home\', \'\*\'\);" style="font-size: 0\.85rem; font-weight: 600; color: var\(--gold\); letter-spacing: 0\.5px; cursor: pointer;">&larr; INÍCIO</div>\s*<div[^>]*>.*?</div>\s*</div>', re.DOTALL)

replacement = r'''<div onclick="window.parent.postMessage('go_home', '*');" style="font-size: 0.85rem; font-weight: 600; color: var(--gold); letter-spacing: 0.5px; cursor: pointer;">&larr; INÍCIO</div>'''

content = pattern.sub(replacement, content)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed hidden second child")
