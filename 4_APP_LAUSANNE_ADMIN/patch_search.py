import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('border:2px solid #eee', 'border:1px solid var(--border-dark); background:var(--navy-main); color:var(--text-light)')
content = content.replace('placeholder="Digite 3 letras ou mais para buscar..."', 'placeholder="Nome"')
content = content.replace('Use a barra acima para pesquisar...', '')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Search input patched.")
