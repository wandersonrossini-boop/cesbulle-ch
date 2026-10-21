import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace PC Sidebar Menu
old_sb_nav = """        <div class="sidebar-nav">
            <div class="nav-link active" onclick="switchCheckinMode('visitor', this)">Visitante</div>
            <div class="nav-link" onclick="switchCheckinMode('child', this)">Criança</div>
            <div class="nav-link" onclick="setTab('events')">Eventos</div>
            <div class="nav-link" onclick="switchCheckinMode('online', this)">Online / QR</div>
            <div class="nav-link" onclick="switchCheckinMode('mural', this)">Mural</div>
        </div>"""
        
# Account for encoding
old_sb_nav_alt = old_sb_nav.replace('Criança', 'Criana')

new_sb_nav = """        <div class="sidebar-nav">
            <div class="nav-link" onclick="switchCheckinMode('mural', this)">P\u00e1gina principal</div>
            <div class="nav-link active" onclick="switchCheckinMode('visitor', this)">Visitantes</div>
            <div class="nav-link" onclick="switchCheckinMode('child', this)">Crian\u00e7as / KIDS</div>
            <div class="nav-link" onclick="setTab('agenda')">Agenda</div>
            <div class="nav-link" onclick="setTab('servir')">Servir</div>
            <div class="nav-link" onclick="setTab('events')">Eventos</div>
        </div>"""

content = content.replace(old_sb_nav, new_sb_nav)
content = content.replace(old_sb_nav_alt, new_sb_nav)

# 2. Replace Mobile Nav & Header
# The user wants "02:05 CME LAUSANNE ☰" for the mobile header.
old_mobile_header = """        <div class="mobile-header">
        <div>
            <h2 class="brand-title">CME LAUSANNE</h2>
            <div class="brand-sub">RECEP\u00c7\u00c3O</div>
        </div>
        <div onclick="window.parent.postMessage('go_home', '*');" style="font-size: 0.85rem; font-weight: 600; color: var(--gold); letter-spacing: 0.5px; cursor: pointer;">&larr; IN\u00cdCIO</div>
    </div>"""

new_mobile_header = """        <div class="mobile-header" style="justify-content: space-between; align-items: center; padding: 15px 20px;">
        <h2 class="brand-title" style="margin:0;">CME LAUSANNE</h2>
        <div onclick="toggleMobileMenu()" style="font-size: 1.5rem; color: #fff; cursor: pointer;">&#9776;</div>
    </div>
    
    <!-- Mobile Sidebar Menu Overlay -->
    <div id="mobile-sidebar" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.8); z-index:9999;">
        <div style="background:var(--bg-dark-sidebar); width:80%; max-width:300px; height:100%; padding:20px; display:flex; flex-direction:column;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:40px;">
                <h2 style="color:#fff; font-size:1.2rem; margin:0; letter-spacing:1px;">CME LAUSANNE</h2>
                <div onclick="toggleMobileMenu()" style="color:#fff; font-size:1.5rem; cursor:pointer;">&times;</div>
            </div>
            
            <div style="display:flex; flex-direction:column; gap:20px;">
                <div style="color:var(--text-light); font-weight:600; cursor:pointer;" onclick="switchCheckinMode('mural'); toggleMobileMenu()">P\u00e1gina principal</div>
                <div style="color:var(--text-light); font-weight:600; cursor:pointer;" onclick="setTab('servir'); toggleMobileMenu()">Escala de culto</div>
                <div style="color:var(--text-light); font-weight:600; cursor:pointer;" onclick="switchCheckinMode('visitor'); toggleMobileMenu()">Enviar mensagem (Check-in)</div>
            </div>
            
            <div style="margin-top:auto; color:var(--text-dim); font-weight:600; cursor:pointer;" onclick="if(typeof AuthManager!=='undefined')AuthManager.logout();">Sair</div>
        </div>
    </div>
    
    <script>
        function toggleMobileMenu() {
            var el = document.getElementById('mobile-sidebar');
            if (el.style.display === 'none') {
                el.style.display = 'block';
            } else {
                el.style.display = 'none';
            }
        }
    </script>
"""
# Replace old mobile header
content = re.sub(r'<div class="mobile-header">.*?</div>\s*</div>', new_mobile_header, content, flags=re.DOTALL)

# Delete bottom-nav
content = re.sub(r'<nav class="bottom-nav">.*?</nav>', '', content, flags=re.DOTALL)


# 3. Simplify Visitantes Tab HTML & Add "Cadastrar & Enviar Link" button
old_visitor_html = """                                    <details style="border:1px solid var(--border-dark); border-radius:12px; padding:12px; background:var(--navy-main); margin-top:10px;">
                                        <summary style="cursor:pointer; font-size:0.82rem; font-weight:800; color:var(--text-light); text-transform:uppercase; letter-spacing:0.5px; user-select:none;">
                                             Mais informa"""

new_visitor_html = """                                    <!-- Informacoes Opcionais (Removidas para simplificar) -->
                                    <div style="display:none;">
                                        <input type="hidden" id="vis-christian" value="nao">
                                        <input type="hidden" id="vis-church" value="">
                                        <input type="hidden" id="vis-invited-by" value="">
                                    </div>
                                    <details style="display:none;">
                                        <summary>Mais informa"""
                                        
content = content.replace(old_visitor_html, new_visitor_html)
content = content.replace(old_visitor_html.replace('informa', 'informa'), new_visitor_html) # Encodings

# Rename submit button
content = content.replace('<span class="btn-text">Registrar entrada</span>', '<span class="btn-text">Cadastrar & Enviar Link</span>')


with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied Reception Structural fixes.")
