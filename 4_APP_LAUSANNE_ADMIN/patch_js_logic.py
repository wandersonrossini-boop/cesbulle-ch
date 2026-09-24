import re
with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f: content = f.read()

# Fix "Use a barra..."
content = content.replace("'<div style=\"color:#aaa; text-align:center; padding:20px; font-style: italic;\">Use a barra acima para pesquisar (Mínimo 3 letras... )</div>'", "'<div style=\"color:var(--text-muted); text-align:center; padding:20px; font-style: italic;\">Digite 3 letras...</div>'")

# Fix "Buscando..."
content = content.replace("'<div style=\"color:#666; text-align:center; padding:20px;\"><br><i class=\"fas fa-circle-notch fa-spin\" style=\"margin-right:8px; color:var(--primary);\"></i> Buscando visitantes...</div>'", "'<div style=\"color:var(--text-muted); text-align:center; padding:20px;\"><br>Buscando...</div>'")
content = content.replace("'<div style=\"color:#666; text-align:center; padding:20px;\"><br>Buscando visitantes...</div>'", "'<div style=\"color:var(--text-muted); text-align:center; padding:20px;\"><br>Buscando...</div>'")

# Fix "Nenhum visitante encontrado"
content = content.replace('color:#854d0e; background:#fefce8; padding:15px; border-radius:12px; border:1px solid #fef08a;', 'color:var(--text-light); background:var(--navy-main); padding:15px; border-radius:12px; border:1px solid var(--border-dark);')
content = content.replace('border-color:#ca8a04; color:#a16207;', 'border-color:var(--gold-main); color:var(--gold-main);')
content = content.replace('<br>Nenhum visitante encontrado com esse nome.<br>', 'Nenhum visitante encontrado.<br>')

# Fix "Erro ao buscar"
content = content.replace('color:#b91c1c; background:#fee2e2;', 'color:#f87171; background:var(--navy-main); border:1px solid var(--border-dark);')

# Fix result cards style
content = content.replace('background:#fff; border:1px solid #e2e8f0; padding:15px; margin-bottom:10px; border-radius:12px; cursor:pointer; color:#333; display:flex; justify-content:space-between; align-items:center; box-shadow:0 2px 5px rgba(0,0,0,0.02); transition: 0.2s;', 'background:var(--navy-card); border:1px solid var(--border-dark); padding:15px; margin-bottom:10px; border-radius:12px; cursor:pointer; color:var(--text-light); display:flex; justify-content:space-between; align-items:center; transition: 0.2s;')

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f: f.write(content)
print("JS logic texts patched.")
