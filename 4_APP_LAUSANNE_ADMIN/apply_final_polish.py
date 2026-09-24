import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove "É um prazer recebê-lo em nossa igreja."
content = content.replace('<p style="color: var(--text-muted); font-size: 0.95rem; margin: 0 0 24px 0;">É um prazer recebê-lo em nossa igreja.</p>', '')
content = content.replace('É um prazer recebê-lo em nossa igreja.', '')

# 2. Remove "Localize cadastros anteriores para registrar nova entrada."
content = content.replace('Localize cadastros anteriores para registrar nova entrada.', '')
content = content.replace('<p style="margin: 0; font-size: 0.9rem; color: #64748B;">Localize cadastros anteriores para registrar nova entrada.</p>', '')

# 3. Enhance touch comfort: increase max-width slightly and input sizes
content = content.replace('max-width: 600px !important;', 'max-width: 700px !important;')
content = content.replace('padding: 14px 16px !important;', 'padding: 16px 20px !important; font-size: 1.1rem !important;')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Final polish applied.")
