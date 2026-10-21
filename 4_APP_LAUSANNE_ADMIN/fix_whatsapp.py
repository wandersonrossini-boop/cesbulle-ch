import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    js = f.read()

# We need to inject the WhatsApp logic into submitVisitor()
# Previously, we added it right after db.collection('people').doc(personId).set(...) in submitVisitor

whatsapp_logic = '''
        // --- WHATSAPP CARTÃO DE CONEXÃO LOGIC ---
        if (isNewPerson && phone && phone.trim() !== '') {
            const cleanPhone = phone.replace(/\\D/g, '');
            if (cleanPhone.length >= 8) {
                const linkCartao = "https://catedral-connect-6c55e.web.app/register_visitor.html?id=" + encodeURIComponent(personId);
                const mensagem = "Olá " + name.trim() + "! Que alegria receber você hoje no CME Lausanne. Para nos conhecermos melhor, por favor preencha rapidamente o seu Cartão de Conexão clicando neste link: " + linkCartao;
                const whatsappUrl = "https://wa.me/" + cleanPhone + "?text=" + encodeURIComponent(mensagem);
                window.open(whatsappUrl, '_blank');
            }
        }
'''

# Find the end of the batch.commit() block in submitVisitor
pattern = r'(batch\.commit\(\)\.then\(\(\) => \{[^}]*?showToast\(.*?sucesso.*?\);)'
js = re.sub(pattern, r'\1' + whatsapp_logic, js, flags=re.DOTALL)

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
    f.write(js)
print("Injected WhatsApp logic.")
