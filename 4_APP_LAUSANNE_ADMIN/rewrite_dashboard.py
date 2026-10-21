import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1 & 3. Fix Topbar Title to CME LAUSANNE, remove Dashboard title
old_topbar_title = '<h2 style="font-size: 1.2rem; font-weight: 800; color: #fff; margin:0; letter-spacing:1px;"><span style="color:var(--gold);">Dashboard</span></h2>'
new_topbar_title = '<h2 style="font-size: 1.2rem; font-weight: 800; color: #fff; margin:0; letter-spacing:1px;">CME LAUSANNE</h2>'
content = content.replace(old_topbar_title, new_topbar_title)

# 1. Remove CES LAUSANNE from sidebar
old_sidebar_brand = """            <div class="sidebar-brand">
                <img src="assets/logo_3.png" height="35" style="filter: drop-shadow(0 0 5px rgba(201, 160, 80, 0.3));">
                <h1 style="font-size: 1.1rem; margin: 0; font-weight: 800; letter-spacing: 1px; color:#fff;">CES LAUSANNE</h1>
            </div>"""
new_sidebar_brand = """            <div class="sidebar-brand">
                <img src="assets/logo_3.png" height="35" style="filter: drop-shadow(0 0 5px rgba(201, 160, 80, 0.3));">
            </div>"""
content = content.replace(old_sidebar_brand, new_sidebar_brand)

# 2. Remove bottom "Sair" from sidebar nav
old_sair_nav = """                <div class="nav-item" onclick="logout()" style="margin-top:auto; border-top:1px solid var(--border); padding-top:15px; color:var(--red);">
                    <i class="fas fa-sign-out-alt"></i>
                    <span>Sair do Painel</span>
                </div>"""
new_sair_nav = ""
content = content.replace(old_sair_nav, new_sair_nav)

# Fix Dashboard HTML Structure
start_dash = content.find('<div id="page-dashboard" class="page-content active">')
end_dash = content.find('<!-- OTHER PAGES PLACEHOLDERS -->')

new_dashboard = """<div id="page-dashboard" class="page-content active">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">
                    <h2 style="font-size: 1.4rem; font-weight: 800; color: #fff; margin:0;">Escalas</h2>
                    <button class="btn-gold" style="width:auto; padding:8px 16px; font-size:0.85rem;" onclick="openNovaEscala()"><i class="fas fa-plus"></i> Criar</button>
                </div>

                <div class="dashboard-grid" style="padding:0; grid-template-columns: 1fr 1fr;">
                    
                    <!-- LEFT COLUMN: ESCALAS -->
                    <div style="display:flex; flex-direction:column; gap:20px;">
                        
                        <!-- NEXT CULTO -->
                        <div class="glass-card" style="background:#111827; border:1px solid #1F2937;">
                            <h3 style="margin-top:0; border-bottom:1px solid #1F2937; padding-bottom:10px; color:var(--text-dim); font-size:0.8rem; text-transform:uppercase; letter-spacing:1px;">Próximo Culto</h3>
                            <div id="proximo-culto-container" style="padding-top:10px; min-height:100px;">
                                <div style="text-align:center; color:var(--text-dim);">Carregando próximo culto...</div>
                            </div>
                        </div>

                        <!-- ESCALAS RECENTES -->
                        <div class="glass-card" style="background:#111827; border:1px solid #1F2937;">
                            <h3 style="margin-top:0; border-bottom:1px solid #1F2937; padding-bottom:10px; color:var(--text-dim); font-size:0.8rem; text-transform:uppercase; letter-spacing:1px;">Escalas Recentes</h3>
                            <div id="escalas-recentes-container" style="padding-top:10px;">
                                <div style="text-align:center; color:var(--text-dim);">Carregando escalas...</div>
                            </div>
                        </div>

                    </div>

                    <!-- RIGHT COLUMN: ATIVIDADE & DIRETRIZES -->
                    <div style="display:flex; flex-direction:column; gap:20px;">
                        
                        <!-- DIRETRIZES PASTORAIS (Only shows if active) -->
                        <div class="glass-card" id="diretrizes-block" style="display:none; background:#111827; border:1px solid #1F2937; border-left:4px solid var(--gold);">
                            <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #1F2937; padding-bottom:10px; margin-bottom:15px;">
                                <h3 style="margin:0; font-size:0.8rem; text-transform:uppercase; letter-spacing:1px; color:#fff;">Diretrizes Pastorais Pendentes</h3>
                                <button onclick="document.getElementById('modal-nova-diretriz').style.display='flex'" style="background:transparent; border:none; color:var(--gold); cursor:pointer; font-size:0.8rem; font-weight:800;"><i class="fas fa-plus"></i></button>
                            </div>
                            <div id="gabinete-active-list" style="overflow-y:auto; max-height:200px;"></div>
                        </div>

                        <!-- ATIVIDADE RECENTE -->
                        <div class="glass-card" style="background:#111827; border:1px solid #1F2937;">
                            <h3 style="margin-top:0; border-bottom:1px solid #1F2937; padding-bottom:10px; color:var(--text-dim); font-size:0.8rem; text-transform:uppercase; letter-spacing:1px;">Atividade Recente</h3>
                            <div id="ata-digital-feed" style="overflow-y:auto; max-height:400px; padding-top:10px; padding-right:5px;">
                                <div style="text-align:center; color:var(--text-dim);">Carregando feed...</div>
                            </div>
                        </div>

                    </div>
                </div>
            </div>

            <!-- OTHER PAGES PLACEHOLDERS -->"""

if start_dash != -1 and end_dash != -1:
    content = content[:start_dash] + new_dashboard + content[end_dash+len('<!-- OTHER PAGES PLACEHOLDERS -->'):]

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Simplified Dashboard in gabinete.html")
