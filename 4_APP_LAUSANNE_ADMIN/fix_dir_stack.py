import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix Diretrizes layout (remove grid, stack them)
old_layout = """                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:20px; margin-top:20px;">
                        <div>
                            <h4 style="color:var(--gold); margin-bottom:15px; border-bottom:1px solid var(--border); padding-bottom:10px;">Ativas</h4>
                            <div id="diretrizes-page-ativas"></div>
                        </div>
                        <div>
                            <h4 style="color:var(--text-dim); margin-bottom:15px; border-bottom:1px solid var(--border); padding-bottom:10px;">Conclu"""
                            
new_layout = """                    <div style="display:flex; flex-direction:column; gap:30px; margin-top:20px;">
                        <div>
                            <h4 style="color:var(--gold); font-size:0.85rem; text-transform:uppercase; margin-bottom:15px; border-bottom:1px solid rgba(255,255,255,0.05); padding-bottom:10px;">Ativas</h4>
                            <div id="diretrizes-page-ativas"></div>
                        </div>
                        <div>
                            <h4 style="color:var(--text-dim); font-size:0.85rem; text-transform:uppercase; margin-bottom:15px; border-bottom:1px solid rgba(255,255,255,0.05); padding-bottom:10px;">Conclu"""

content = content.replace(old_layout, new_layout)
# Also try replacing the broken encoding version just in case
content = content.replace(old_layout.replace('Conclu', 'Conclu'), new_layout)


# Remove the <p> intro text because regex failed due to encoding
content = re.sub(r'<p style="color:var\(--text-dim\);">Envie ordens e instru.*?es diretamente ao painel da secretaria e acompanhe a resolu.*?o.</p>', '', content)

# Fix the button
content = content.replace('<i class="fas fa-plus"></i> Despachar Diretriz', 'DESPACHAR DIRETRIZ')

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed Diretrizes layout and text.")
