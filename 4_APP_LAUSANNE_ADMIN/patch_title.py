import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Add subtitle inside the new visitor block
target_block = '''<h2 style="font-size: 1.25rem; font-weight: 700; color: #0f172a; margin: 0 0 16px 0;">Registrar Entrada</h2>'''
replacement = '''<h2 style="font-size: 1.8rem; font-weight: 700; color: var(--text-light); margin: 0 0 5px 0; font-family: var(--font-serif);">Visitante</h2>
<p style="color: var(--text-muted); font-size: 0.95rem; margin: 0 0 24px 0;">É um prazer recebê-lo em nossa igreja.</p>'''
content = content.replace(target_block, replacement)

# Remove the old page-title
content = re.sub(r'<div style="margin-bottom: 20px;">\s*<p class="page-subtitle-top".*?</p>\s*<h1 class="page-title".*?</h1>\s*</div>', '', content, flags=re.DOTALL)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Title patched.")
