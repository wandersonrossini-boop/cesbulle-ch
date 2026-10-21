import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix mobile header
pattern = re.compile(r'(<div class="mobile-header">.*?<div class="brand-sub">.*?</div>\s*</div>\s*)(<div[^>]*onclick="document\.querySelector\(\'\.sidebar-nav\'\)\.classList\.toggle\(\'show-mobile\'\)"[^>]*>.*?</div>)', re.DOTALL)
replacement = r'\1<div style="display: flex; gap: 15px; align-items: center;"><div onclick="window.parent.postMessage(\'go_home\', \'*\');" style="font-size: 0.85rem; font-weight: 600; color: var(--gold); letter-spacing: 0.5px; cursor: pointer;">&larr; INÍCIO</div>\2</div>'

content = pattern.sub(replacement, content)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Mobile header updated")
