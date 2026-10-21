import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

# We will replace from "alert("Check-in de " + name + " registrado com sucesso!");"
old_alert = 'alert("Check-in de " + name + " registrado com sucesso!");'

new_alert = """        // WhatsApp Integration for Visitor Connect Card
        if (phone) {
            const cleanPhone = phone.replace(/\D/g, '');
            const formUrl = `https://catedral-connect-6c55e.web.app/visitor_form?phone=${cleanPhone}`;
            const msg = encodeURIComponent(`Olá, ${name}! Que alegria ter você na CME Lausanne hoje. Clique neste link rápido para nos contar mais sobre você e deixar seu pedido de oração: ${formUrl}`);
            const waUrl = `https://wa.me/${cleanPhone}?text=${msg}`;
            window.open(waUrl, '_blank');
        } else {
            alert("Check-in de " + name + " registrado (sem telefone para enviar o link).");
        }"""

content = content.replace(old_alert, new_alert)

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("WhatsApp logic injected successfully.")
