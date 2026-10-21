import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Clean Diretrizes Concluidas
pattern_concluidas = re.compile(r'<div style="background:rgba\(255,255,255,0\.02\);.*?</div>\s*<i class="fas fa-check-circle".*?</i>\s*</div>', re.DOTALL)
new_concluidas = """<div style="padding:15px 0; border-bottom:1px solid rgba(255,255,255,0.1); margin-bottom:0;">
                                    <div style="font-weight:800; color:#cbd5e1; font-size:0.95rem;">${d.titulo}</div>
                                    <div style="font-size:0.8rem; color:var(--text-dim); margin-top:5px;">${d.tipo} &middot; Conclu\u00edda em ${dateObj.toLocaleDateString('pt-BR')}</div>
                                </div>"""
content = re.sub(pattern_concluidas, new_concluidas, content)

# 2. Fix Ordens Layout
pattern_ordens = re.compile(r'<div style="background:rgba\(255,255,255,0\.02\); border:1px solid var\(--border\); border-left:4px solid \$\{badgeColor\}; border-radius:12px; padding:15px; margin-bottom:12px;">\s*<div style="display:flex; justify-content:space-between; font-size:0\.75rem; color:#94a3b8; margin-bottom:5px;">.*?</div>\s*</div>', re.DOTALL)
new_ordens = """<div style="padding:15px 0; border-bottom:1px solid rgba(255,255,255,0.1); margin-bottom:0;">
                            <div style="font-weight:800; color:#f8fafc; font-size:0.95rem;">${d.titulo}</div>
                            <div style="font-size:0.85rem; color:#cbd5e1; margin-top:5px; margin-bottom:10px;">${d.descricao}</div>
                            <div style="display:flex; justify-content:space-between; align-items:center; font-size:0.8rem; color:var(--text-dim);">
                                <span>${d.tipo} &middot; ${dateObj.toLocaleDateString('pt-BR')} &middot; Status: <strong>${d.status.toUpperCase()}</strong></span>
                                ${d.status === 'pendente' ? `<button onclick="concluirDiretriz('${doc.id}')" style="background:transparent; border:1px solid rgba(255,255,255,0.3); color:#f8fafc; padding:4px 10px; border-radius:4px; font-weight:600; font-size:0.75rem; cursor:pointer;">Concluir</button>` : ''}
                            </div>
                        </div>"""
content = re.sub(pattern_ordens, new_ordens, content)

# 3. Clean Settings (Configuracoes)
content = re.sub(r'<div class="nav-item" onclick="switchPage\(\'settings\'\)" id="nav-settings">.*?</div>', '', content, flags=re.DOTALL)
content = re.sub(r'<div id="page-settings" class="page-content">.*?</div>\s*</main>', '</main>', content, flags=re.DOTALL)
# Also remove settings from switchPage
content = re.sub(r"'settings': 'Configura\w*es'?", '', content)

# 4. Clean "Sair" button in Sidebar
pattern_sair = re.compile(r'<div class="nav-item" onclick="AuthManager\.logout\(\)" style="color:#ef4444;">.*?</div>', re.DOTALL)
new_sair = """<div style="cursor:pointer; color:var(--text-dim); padding:15px; font-weight:600; margin-top:20px;" onclick="AuthManager.logout()">Sair</div>"""
content = re.sub(pattern_sair, new_sair, content)

# 5. Clean Logo Sidebar
pattern_brand = re.compile(r'<div class="sidebar-brand">.*?</div>', re.DOTALL)
new_brand = """<div class="sidebar-brand" style="padding: 25px 15px 10px 15px; font-weight:900; font-size:1.1rem; color:#fff; letter-spacing:1px;">
                CME LAUSANNE
            </div>"""
content = re.sub(pattern_brand, new_brand, content)

# 6. Remove remaining intro texts (e.g., "Envie ordens e instruções...")
content = re.sub(r'<p style="color:var\(--text-dim\); margin-top:10px;">.*?</p>', '', content)

# 7. Button texts: remove any "+" left, fix casing.
# I will just write replacements for the known ones.
content = content.replace('Criar', 'CRIAR') # Assuming standard is caps, wait, user said "DESPACHAR DIRETRIZ" in uppercase
content = content.replace('Despachar diretriz', 'DESPACHAR DIRETRIZ')
content = content.replace('Nova ordem', 'NOVA ORDEM')
content = content.replace('Adicionar minist\u00e9rio', 'ADICIONAR MINIST\u00c9RIO')
content = content.replace('Adicionar l\u00edder', 'ADICIONAR L\u00cdDER')

# 8. Check empty space in Diretrizes Ativas
# Usually caused by glass-card min-height or grid layout. We will remove glass-card style.
content = content.replace('class="glass-card"', '')

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied massive UI strip.")
