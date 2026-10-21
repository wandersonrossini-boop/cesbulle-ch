import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

modal_html = '''
    <div id="modal-mais" class="modal-mais">
        <div class="modal-mais-content">
            <div class="modal-mais-header">
                <i class="fas fa-times" onclick="document.getElementById('modal-mais').style.display='none';" style="cursor: pointer; font-size: 1.2rem; color: #94A3B8;"></i>
            </div>
            
            <div class="modal-mais-btn" onclick="openEscalaMobile()">Escala de culto</div>
            <div class="modal-mais-btn" onclick="window.parent.postMessage('go_home', '*'); document.getElementById('modal-mais').style.display='none';">Enviar mensagem (Check-in)</div>
            
            <div class="modal-mais-divider"></div>
            
            <div class="modal-mais-btn gold" onclick="window.parent.postMessage('go_home', '*'); document.getElementById('modal-mais').style.display='none';">Página principal</div>
            <div class="modal-mais-btn" onclick="logout()">Sair</div>
        </div>
    </div>
'''

content = content.replace('</body>', modal_html + '\n</body>')

# Update col-e with mobile header
col_e_target = '''            <div class="feed-col active" id="col-e">
                <div class="col-header" style="display:flex; justify-content:space-between; align-items:center;">
                    <h2>Escala de Culto</h2>
                    <button id="btn-print-escala" onclick="printActiveEscala()" style="background:var(--gold-dim); border:1px solid var(--border); color:var(--gold); border-radius:8px; padding:6px 15px; cursor:pointer; font-size:0.8rem; font-weight:800; display:none; transition: all 0.3s ease;">
                        <i class="fas fa-file-pdf"></i> Compartilhar PDF
                    </button>
                </div>'''

col_e_replacement = '''            <div class="feed-col active" id="col-e">
                <div class="mobile-escala-header">
                    <i class="fas fa-arrow-left" onclick="closeEscalaMobile()" style="cursor:pointer; font-size:1.2rem; color:#fff;"></i>
                    <h2 style="font-family: var(--font-heading); font-size: 1rem; color: #fff; margin:0; text-transform:uppercase; letter-spacing:1px; font-weight:700;">Escala de Culto</h2>
                </div>
                <div class="col-header" style="display:flex; justify-content:space-between; align-items:center;">
                    <h2>Escala de Culto</h2>
                    <button id="btn-print-escala" onclick="printActiveEscala()" style="background:var(--gold-dim); border:1px solid var(--border); color:var(--gold); border-radius:8px; padding:6px 15px; cursor:pointer; font-size:0.8rem; font-weight:800; display:none; transition: all 0.3s ease;">
                        <i class="fas fa-file-pdf"></i> Compartilhar PDF
                    </button>
                </div>'''
content = content.replace(col_e_target, col_e_replacement)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("HTML updated")
