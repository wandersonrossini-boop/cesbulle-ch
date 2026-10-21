import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '''<div class="modal-mais-btn" onclick="window.parent.postMessage('go_home', '*'); document.getElementById('modal-mais').style.display='none';">Enviar mensagem (Check-in)</div>''', 
    '''<div class="modal-mais-btn" onclick="alert('Função em desenvolvimento'); document.getElementById('modal-mais').style.display='none';">Enviar mensagem (Check-in)</div>'''
)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Alert added")
