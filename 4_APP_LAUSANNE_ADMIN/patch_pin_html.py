import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update HTML of pin-screen
pin_screen_target = '''        <!-- PIN / LOGIN SCREEN -->
        <div id="pin-screen">
            <div class="pin-container">
                <h2 style="font-family: var(--font-heading); font-weight: 800; margin-bottom: 24px; letter-spacing: 2px; color: #fff; font-size: 1.2rem; text-transform: uppercase;">ACESSO AO MÓDULO</h2>
                
                <div id="pin-input-wrapper">
                    <input type="password" id="pin-input" class="pin-input" placeholder="">
                </div>'''
pin_screen_replacement = '''        <!-- PIN / LOGIN SCREEN -->
        <div id="pin-screen">
            <div class="pin-container">
                <h2 id="pin-screen-title" style="font-family: var(--font-heading); font-weight: 800; margin-bottom: 4px; letter-spacing: 1px; color: #fff; font-size: 1.3rem; text-transform: uppercase;">ACESSO À RECEPÇÃO</h2>
                <h3 id="pin-screen-subtitle" style="font-family: var(--font-main); font-weight: 600; margin-bottom: 32px; color: var(--gold); font-size: 0.9rem; text-transform: uppercase;">CME LAUSANNE<br><span id="pin-screen-subtext" style="font-weight: 400; color: #94A3B8; font-size: 0.8rem; text-transform: none;">Área de Recepção</span></h3>
                
                <div id="pin-input-wrapper">
                    <input type="password" id="pin-input" class="pin-input" placeholder="••••••">
                </div>'''

content = content.replace(pin_screen_target, pin_screen_replacement)

# Update return button
return_btn_target = '''<p onclick="showRoles()" style="margin-top:20px; color:#94A3B8; font-size:0.8rem; cursor:pointer; font-weight:700; text-transform: uppercase; letter-spacing: 1px;">Voltar aos Módulos</p>'''
return_btn_replacement = '''<div onclick="showRoles()" style="margin-top:24px; color:#94A3B8; font-size:0.85rem; cursor:pointer; font-weight:600; display: flex; align-items: center; justify-content: center; gap: 8px; transition: color 0.2s;" onmouseover="this.style.color='#fff'" onmouseout="this.style.color='#94A3B8'">
                    <i class="fas fa-arrow-left"></i> Voltar ao menu
                </div>'''
content = content.replace(return_btn_target, return_btn_replacement)


with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("HTML replaced")
