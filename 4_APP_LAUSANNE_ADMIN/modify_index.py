import re

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. Clean the top bar (Remove ES logo / avatar)
# Replace the whole <div class="portal-top-bar">...</div> with a cleaner one
top_bar_pattern = r'<div class="portal-top-bar">.*?</div>\s*</div>'
clean_top_bar = '''<div class="portal-top-bar">
            <div class="portal-brand">
                <span class="portal-brand-text">CME Lausanne</span>
            </div>
        </div>'''
# Actually, the original was:
# <div class="portal-top-bar">
#     <div class="portal-brand">
#         <img src="assets/logo_3.png?v=70.3.106" alt="CME Lausanne Logo">
#         <span class="portal-brand-text">CME Lausanne</span>
#     </div>
#     <div class="avatar-circle">
#         <img src="assets/logo_3.png?v=70.3.106" alt="Logo avatar">
#     </div>
# </div>
# Let's keep the logo but remove the avatar.
html = re.sub(r'<div class="avatar-circle">.*?</div>', '', html, flags=re.DOTALL)

# 2. Section Titles
html = html.replace('<div class="section-title"><span>OPERAÇÃO</span> DO CULTO</div>', '<div class="section-title">OPERAÇÃO</div>')
html = html.replace('<div class="section-title"><span>ÁREAS</span> ADMINISTRATIVAS</div>', '<div class="section-title">GESTÃO</div>')

# 3. Remove "Acessar" text but keep the arrow to respect "Nao criar um novo design" but clean redundant text.
html = html.replace('<span class="op-action-text">Acessar</span>', '')

# 4. Remove the Footer Bar completely
html = re.sub(r'<!-- Footer Bar -->\s*<div class="footer-bar">.*?</div>', '', html, flags=re.DOTALL)

# 5. Fix card order/titles just in case
# OPERACAO: Altar, Recepcao, Kids (already in this order in HTML)
# GESTAO: Gabinete Pastoral, Integracao, Secretaria (already in this order in HTML)
# Rename Gabinete Pastoral to PASTORAL to match the user's sketch? The user said PASTORAL, SECRETARIA, INTEGRAÇÃO.
html = html.replace('<h4>Gabinete Pastoral</h4>', '<h4>Pastoral</h4>')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("Modification complete.")
