import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the display:none for pc-column-right
content = content.replace('.pc-column-right { display: none !important; }', '/* .pc-column-right restored */')

# Wrap the ultimas-entradas-container in a details block
content = content.replace('<div class="ultimas-entradas-container" style="margin-top: 5px;">',
'''<details class="ultimas-entradas-details" style="margin-top: 30px; border: 1px solid var(--border-dark); border-radius: 8px; padding: 15px; background: var(--navy-main);">
    <summary style="cursor: pointer; color: var(--gold-main); font-weight: 700; font-size: 0.95rem; text-transform: uppercase;">
        Ver Últimas Entradas
    </summary>
    <div class="ultimas-entradas-container" style="margin-top: 15px;">''')

# We need to close the details block at the end of the container. 
# It ends right before </div> <!-- END pc-column-right -->
content = content.replace('</div> <!-- END pc-column-right -->', '</details>\n                        </div> <!-- END pc-column-right -->')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Ultimas entradas patched.")
