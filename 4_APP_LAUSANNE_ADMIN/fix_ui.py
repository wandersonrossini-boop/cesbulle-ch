import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix Top Header
top_header_pattern = re.compile(r'<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">\s*<div style="display:flex; align-items:center; gap:15px;">.*?</div>\s*</div>', re.DOTALL)

new_top_header = """<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:30px; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 20px;">
                <h2 style="margin:0; font-size:1.3rem; color:#f8fafc; font-weight:800; letter-spacing:2px;">CME LAUSANNE</h2>
                <button onclick="AuthManager.logout()" style="background:transparent; color:var(--text-dim); border:none; cursor:pointer; font-weight:600; font-size: 0.9rem;">Sair <i class="fas fa-sign-out-alt"></i></button>
            </div>"""

content = re.sub(r'<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">\s*<div style="display:flex; align-items:center; gap:15px;">.*?</div>\s*</div>', new_top_header, content, flags=re.DOTALL)

# Also remove the `current-page-title` update in switchPage
content = re.sub(r"document\.getElementById\('current-page-title'\)\.innerText = titles\[pageId\] \|\| 'Gabinete';\n", "", content)

# 2. Fix Sidebar hierarchy
sidebar_pattern = re.compile(r'<nav class="sidebar-nav">.*?</nav>', re.DOTALL)
new_sidebar = """<nav class="sidebar-nav">
                <div style="font-size: 0.65rem; color: var(--text-dim); font-weight: 800; text-transform: uppercase; letter-spacing: 1px; margin: 15px 0 10px 15px;">Opera\u00e7\u00e3o</div>
                <div class="nav-item active" onclick="switchPage('dashboard')" id="nav-dashboard">
                    <i class="fas fa-calendar-alt"></i>
                    <span>Escalas</span>
                </div>
                
                <div style="font-size: 0.65rem; color: var(--text-dim); font-weight: 800; text-transform: uppercase; letter-spacing: 1px; margin: 25px 0 10px 15px;">Registros</div>
                <div class="nav-item" onclick="switchPage('ata')" id="nav-ata">
                    <i class="fas fa-history"></i>
                    <span>Ata Digital</span>
                </div>
                <div class="nav-item" onclick="switchPage('relatorios')" id="nav-relatorios">
                    <i class="fas fa-chart-bar"></i>
                    <span>Relat\u00f3rios</span>
                </div>

                <div style="font-size: 0.65rem; color: var(--text-dim); font-weight: 800; text-transform: uppercase; letter-spacing: 1px; margin: 25px 0 10px 15px;">Gest\u00e3o</div>
                <div class="nav-item" onclick="switchPage('lideres')" id="nav-lideres">
                    <i class="fas fa-users"></i>
                    <span>L\u00edderes</span>
                </div>
                <div class="nav-item" onclick="switchPage('ministerios')" id="nav-ministerios">
                    <i class="fas fa-sitemap"></i>
                    <span>Minist\u00e9rios</span>
                </div>
                <div class="nav-item" onclick="switchPage('ordens')" id="nav-ordens">
                    <i class="fas fa-tasks"></i>
                    <span>Ordens</span>
                </div>
                <div class="nav-item" onclick="switchPage('diretrizes')" id="nav-diretrizes">
                    <i class="fas fa-book"></i>
                    <span>Diretrizes</span>
                </div>
                <div class="nav-item" onclick="switchPage('settings')" id="nav-settings">
                    <i class="fas fa-cog"></i>
                    <span>Configura\u00e7\u00f5es</span>
                </div>
            </nav>"""
content = re.sub(sidebar_pattern, new_sidebar, content)

# 3. Simplify 'Atividade Recente (Real-Time)' to 'ATIVIDADE RECENTE'
content = content.replace('ATIVIDADE RECENTE <span style="font-size:0.7rem; font-weight:normal; color:#ef4444;">(Real-Time)</span>', 'ATIVIDADE RECENTE')

# 4. Modify Cards CSS (background:#111827; border:1px solid #1F2937)
content = content.replace('background:#111827; border:1px solid #1F2937; border-radius:12px; padding:20px; flex:1;', 'background:transparent; border:1px solid rgba(255,255,255,0.03); border-radius:0; padding:15px; flex:1;')
content = content.replace('background:#111827; border:1px solid #1F2937; border-radius:12px; padding:20px; width:350px;', 'background:transparent; border:1px solid rgba(255,255,255,0.03); border-radius:0; padding:15px; width:320px;')

# 5. Fix loadAtaDigitalFeed logic
old_feed_logic = """                        html += `
                            <div style="display:flex; gap:15px; margin-bottom:15px; background:#1e293b; padding:15px; border-radius:12px; border-left:3px solid ${color};">
                                <div style="min-width:60px; text-align:right;">
                                    <div style="font-size:0.7rem; color:#94a3b8; font-weight:800;">${dateObj.toLocaleDateString('pt-BR').substring(0,5)}</div>
                                    <div style="font-size:0.7rem; color:#64748b;">${dateObj.toLocaleTimeString('pt-BR', {hour: '2-digit', minute:'2-digit'})}</div>
                                </div>
                                <div>
                                    <div style="font-size:0.75rem; color:${color}; font-weight:800; text-transform:uppercase; margin-bottom:3px;">${d.tipo}</div>
                                    <div style="font-size:0.9rem; color:#f8fafc;">${d.descricao}</div>
                                    <div style="font-size:0.7rem; color:#64748b; margin-top:4px;"><i class="fas fa-user-circle"></i> Resp: ${d.responsavel}</div>
                                </div>
                            </div>
                        `;"""

new_feed_logic = """                        // Simplify description
                        let shortDesc = d.descricao;
                        if(shortDesc.includes("foi registrado(a) pela primeira vez no sistema")) {
                            let nome = shortDesc.split(" foi ")[0];
                            nome = nome.charAt(0).toUpperCase() + nome.slice(1);
                            shortDesc = `${nome} entrou`;
                        } else if (shortDesc.includes("publicou uma nova escala")) {
                            let partes = shortDesc.split("nova escala de culto: ");
                            if (partes.length > 1) {
                                shortDesc = `Escala criada: ${partes[1].split(" para ")[0]}`;
                            }
                        }

                        let timeStr = dateObj.toLocaleTimeString('pt-BR', {hour: '2-digit', minute:'2-digit'});

                        html += `
                            <div style="padding:10px 0; border-bottom:1px solid rgba(255,255,255,0.03); display:flex; gap:15px; align-items:baseline;">
                                <div style="color:var(--text-dim); font-size:0.85rem; min-width:45px; font-variant-numeric: tabular-nums;">${timeStr}</div>
                                <div style="font-size:0.9rem; color:#cbd5e1;">${shortDesc}</div>
                            </div>
                        `;"""

content = content.replace(old_feed_logic, new_feed_logic)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied UI fixes.")
