import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Sidebar Icons
nav_pattern = re.compile(r'<nav class="sidebar-nav">.*?</nav>', re.DOTALL)
def clean_nav(match):
    nav_content = match.group(0)
    # Remove all <i> tags in the nav
    nav_content = re.sub(r'\s*<i class="fas fa-.*?"></i>\s*', '', nav_content)
    return nav_content
content = re.sub(nav_pattern, clean_nav, content)

# 2. Clean Page Headers (h3) and Subtitles (p)
# Example: <h3 ...><i class="fas fa-users"></i> Gestão de Líderes</h3>
def clean_headers(match):
    h3_content = match.group(0)
    # Remove icon
    h3_content = re.sub(r'<i class="fas fa-.*?"></i>\s*', '', h3_content)
    # Rename specific titles
    h3_content = h3_content.replace('Gestão de Líderes', 'Líderes')
    h3_content = h3_content.replace('Ministérios Lausanne', 'Ministérios')
    h3_content = h3_content.replace('Ordens Pastorais', 'Ordens')
    h3_content = h3_content.replace('Despacho de Diretrizes', 'Diretrizes')
    h3_content = h3_content.replace('Configurações do Gabinete', 'Configurações')
    return h3_content

content = re.sub(r'<h3.*?</h3>', clean_headers, content)
# Remove all explanatory <p> right under <h3>
content = re.sub(r'</h3>\s*<p style="color:var\(--text-dim\); margin-top:10px;">.*?</p>', '</h3>', content, flags=re.DOTALL)

# 3. Clean Configurações Page
settings_pattern = re.compile(r'<div id="page-settings" class="page-content">.*?</div>\s*</main>', re.DOTALL)
new_settings = """<div id="page-settings" class="page-content">
                <div style="padding-top:10px;">
                    <h3 style="color:var(--gold); border-bottom:1px solid rgba(255,255,255,0.1); padding-bottom:15px; margin-bottom:20px; font-size:1.1rem;">Configura\u00e7\u00f5es</h3>
                    <div style="margin-bottom:10px; font-weight:700; color:#fff;">Acesso e seguran\u00e7a</div>
                    <div style="color:var(--text-dim); font-size:0.9rem;">Para alterar chaves de acesso ou dados cadastrais, utilize o painel administrativo.</div>
                </div>
            </div>
        </main>"""
content = re.sub(settings_pattern, new_settings, content)

# 4. Clean Buttons (e.g. + DESPACHAR DIRETRIZ)
# Look for + CRIAR, + DESPACHAR, etc.
content = content.replace('<i class="fas fa-plus"></i> CRIAR', 'Criar')
content = content.replace('<i class="fas fa-plus"></i> Criar', 'Criar')
content = content.replace('<i class="fas fa-plus"></i> DESPACHAR DIRETRIZ', 'Despachar diretriz')
content = content.replace('<i class="fas fa-plus"></i> Nova Ordem', 'Nova ordem')
content = content.replace('<i class="fas fa-plus"></i> Adicionar Minist\u00e9rio', 'Adicionar minist\u00e9rio')
content = content.replace('<i class="fas fa-plus"></i> Adicionar L\u00edder', 'Adicionar l\u00edder')

# 5. Simplify Diretrizes JS logic
# Need to rewrite loadDiretrizes() completely.
# Let's find it and replace the rendering logic.
# (We'll do this in the next script if this file gets too big, but let's try replacing specific HTML outputs in JS).

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied strict structural cleanup to HTML.")
