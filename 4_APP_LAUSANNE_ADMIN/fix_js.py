import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Modify submitVisitor to open WhatsApp
# It currently has something like this at the end:
#         document.getElementById('vis-name').value = '';
#         document.getElementById('vis-phone').value = '';
#         alert("Visitante registrado com sucesso!");
# We will inject the WhatsApp logic before or instead of the alert.

old_submit = """        document.getElementById('vis-name').value = '';
        document.getElementById('vis-phone').value = '';
        if (btn && btn.tagName === 'BUTTON') {
            btn.disabled = false;
            btn.innerText = originalText;
            btn.style.opacity = '1';
        }
        
        alert("Entrada de visitante registrada com sucesso!");"""

new_submit = """        document.getElementById('vis-name').value = '';
        document.getElementById('vis-phone').value = '';
        if (btn && btn.tagName === 'BUTTON') {
            btn.disabled = false;
            btn.innerText = originalText;
            btn.style.opacity = '1';
        }
        
        // WhatsApp Integration for Visitor Connect Card
        if (phone) {
            // Remove + and spaces
            const cleanPhone = phone.replace(/\\D/g, '');
            const formUrl = `https://catedral-connect-6c55e.web.app/visitor_form?phone=${cleanPhone}`;
            const msg = encodeURIComponent(`Olá, ${name}! Que alegria ter você na CME Lausanne hoje. Clique neste link rápido para nos contar mais sobre você e deixar seu pedido de oração: ${formUrl}`);
            const waUrl = `https://wa.me/${cleanPhone}?text=${msg}`;
            window.open(waUrl, '_blank');
        } else {
            alert("Visitante registrado (sem telefone para envio de link).");
        }"""

content = content.replace(old_submit, new_submit)

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied WhatsApp logic to submitVisitor.")
