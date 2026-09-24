import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the "Encontrar Visitante (Já Visitou)" block
target = '''<div style="display: flex; align-items: center; margin-bottom: 15px;">
                                    <div style="width: 40px; height: 40px; border-radius: 50%; background: rgba(255, 179, 0, 0.1); display: flex; align-items: center; justify-content: center; margin-right: 12px;">
                                        
                                    </div>
                                    <div>
                                        <h3 class="title-modern" style="color:var(--primary); margin:0; font-size: 1.3rem;">Encontrar Visitante (Já Visitou)</h3>
                                        <p style="color:var(--text-muted); font-size:0.8rem; margin:2px 0 0 0;"></p>
                                    </div>
                                </div>'''
replacement = '''<h2 style="font-size: 1.8rem; font-weight: 700; color: var(--text-light); margin: 0 0 24px 0; font-family: var(--font-serif);">Já visitou</h2>'''

content = content.replace(target, replacement)

# Change the placeholder or label for search
content = content.replace('placeholder="Buscar nome do visitante..."', 'placeholder="Nome"')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Ja visitou patched.")
