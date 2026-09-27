import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Hide visitor-sub-exist by default
content = content.replace('<div id="visitor-sub-exist" class="visitor-sub-area" style="text-align:left;">', '<div id="visitor-sub-exist" class="visitor-sub-area" style="text-align:left; display:none;">')

# 2. Move the submit button to the end of the form
# Find the button block
btn_match = re.search(r'<!-- Botão Principal de Registro -->\s*<button onclick="submitVisitor\(\)" class="submit-btn-container" id="btn-submit-visitor">[\s\S]*?</button>\s*', content)
if btn_match:
    btn_html = btn_match.group(0)
    # Remove it from the current position
    content = content.replace(btn_html, '')
    
    # Insert it after the details block
    details_end = '</details>'
    details_end_pos = content.find(details_end, content.find('<!-- Informações Opcionais (Gaveta Retrátil) -->'))
    if details_end_pos != -1:
        insert_pos = details_end_pos + len(details_end)
        content = content[:insert_pos] + '\n\n                                    ' + btn_html + content[insert_pos:]

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Button moved and search hidden.")
