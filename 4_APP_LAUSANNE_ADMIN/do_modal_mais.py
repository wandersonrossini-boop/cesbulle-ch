import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Let's find the Mais modal and update its CSS
old_modal_css = '''        .modal-mais {
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            z-index: 2000;
            display: none;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .modal-mais-content {
            background: #121418;
            border: 1px solid var(--border);
            border-radius: 16px;
            width: 100%;
            max-width: 320px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.5);
            overflow: hidden;
            animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .modal-mais-header {
            padding: 15px 20px;
            display: flex;
            justify-content: flex-end;
        }
        .modal-mais-btn {
            padding: 16px 25px;
            color: #E2E8F0;
            font-size: 0.95rem;
            font-weight: 500;
            cursor: pointer;
            transition: 0.2s;
        }
        .modal-mais-btn:active { background: rgba(255,255,255,0.05); }
        .modal-mais-btn.gold { color: var(--gold); }
        .modal-mais-divider { height: 1px; background: rgba(255,255,255,0.05); margin: 5px 20px; }'''

new_modal_css = '''        .modal-mais {
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.7);
            backdrop-filter: blur(5px);
            -webkit-backdrop-filter: blur(5px);
            z-index: 2000;
            display: none;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .modal-mais-content {
            background: #121418;
            border: 1px solid var(--border);
            border-radius: 20px;
            width: 100%;
            max-width: 300px;
            box-shadow: 0 20px 50px rgba(0,0,0,0.6);
            overflow: hidden;
            animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
            padding-bottom: 10px;
        }
        .modal-mais-header {
            padding: 20px;
            display: flex;
            justify-content: flex-end;
        }
        .modal-mais-btn {
            padding: 18px 25px;
            color: #E2E8F0;
            font-size: 0.85rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            cursor: pointer;
            transition: 0.2s;
        }
        .modal-mais-btn:active { background: rgba(255,255,255,0.03); }
        .modal-mais-btn.gold { color: var(--gold); }
        .modal-mais-divider { height: 1px; background: rgba(255,255,255,0.05); margin: 0 25px; }
        .modal-mais-spacer { height: 20px; }'''

content = content.replace(old_modal_css, new_modal_css)


# 2. Update the HTML for the modal
old_modal_html = '''    <div id="modal-mais" class="modal-mais">
        <div class="modal-mais-content">
            <div class="modal-mais-header">
                <i class="fas fa-times" onclick="document.getElementById('modal-mais').style.display='none';" style="cursor: pointer; font-size: 1.2rem; color: #94A3B8;"></i>
            </div>
            
            <div class="modal-mais-btn" onclick="openEscalaMobile()">Escala de culto</div>
            <div class="modal-mais-btn" onclick="alert('Função em desenvolvimento'); document.getElementById('modal-mais').style.display='none';">Enviar mensagem (Check-in)</div>
            
            <div class="modal-mais-divider"></div>
            
            <div class="modal-mais-btn gold" onclick="window.parent.postMessage('go_home', '*'); document.getElementById('modal-mais').style.display='none';">Página principal</div>
            <div class="modal-mais-btn" onclick="logout()">Sair</div>
        </div>
    </div>'''

new_modal_html = '''    <div id="modal-mais" class="modal-mais">
        <div class="modal-mais-content">
            <div class="modal-mais-header">
                <i class="fas fa-times" onclick="document.getElementById('modal-mais').style.display='none';" style="cursor: pointer; font-size: 1.4rem; color: #64748B;"></i>
            </div>
            
            <div class="modal-mais-btn gold" onclick="window.parent.postMessage('go_home', '*'); document.getElementById('modal-mais').style.display='none';">Página principal</div>
            <div class="modal-mais-divider"></div>
            <div class="modal-mais-btn" onclick="openEscalaMobile()">Escala de culto</div>
            <div class="modal-mais-divider"></div>
            <div class="modal-mais-btn" onclick="alert('Função em desenvolvimento'); document.getElementById('modal-mais').style.display='none';">Enviar mensagem (Check-in)</div>
            
            <div class="modal-mais-spacer"></div>
            <div class="modal-mais-divider"></div>
            
            <div class="modal-mais-btn" style="color: #94A3B8;" onclick="logout()">Sair</div>
        </div>
    </div>'''

content = content.replace(old_modal_html, new_modal_html)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Modal Mais updated")
