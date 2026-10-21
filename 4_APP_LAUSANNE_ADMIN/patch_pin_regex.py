import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the HTML block dynamically
import re

pattern = re.compile(r'<div id="pin-screen">\s*<div class="pin-container">\s*<h2[^>]*>.*?</h2>\s*<div id="pin-input-wrapper">', re.IGNORECASE | re.DOTALL)
replacement = '''<div id="pin-screen">
            <div class="pin-container">
                <h2 id="pin-screen-title" style="font-family: var(--font-heading); font-weight: 800; margin-bottom: 4px; letter-spacing: 1px; color: #fff; font-size: 1.3rem; text-transform: uppercase;">ACESSO À RECEPÇÃO</h2>
                <h3 id="pin-screen-subtitle" style="font-family: var(--font-main); font-weight: 600; margin-bottom: 32px; color: var(--gold); font-size: 0.9rem; text-transform: uppercase;">CME LAUSANNE<br><span id="pin-screen-subtext" style="font-weight: 400; color: #94A3B8; font-size: 0.8rem; text-transform: none;">Área de Recepção</span></h3>
                
                <div id="pin-input-wrapper">'''

content = pattern.sub(replacement, content)

# update placeholder for pin-input
content = content.replace('id="pin-input" class="pin-input" placeholder=""', 'id="pin-input" class="pin-input" placeholder="••••••"')

# update return button
pattern2 = re.compile(r'<p onclick="showRoles\(\)"[^>]*>.*?</p>', re.IGNORECASE | re.DOTALL)
replacement2 = '''<div onclick="showRoles()" style="margin-top:24px; color:#94A3B8; font-size:0.85rem; cursor:pointer; font-weight:600; display: flex; align-items: center; justify-content: center; gap: 8px; transition: color 0.2s;" onmouseover="this.style.color='#fff'" onmouseout="this.style.color='#94A3B8'">
                    <i class="fas fa-arrow-left"></i> Voltar ao menu
                </div>'''
content = pattern2.sub(replacement2, content)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Regex applied")
