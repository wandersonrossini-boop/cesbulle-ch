import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('async function loadGabineteCards() {')
end = content.find('async function salvarDiretrizPastoral(btn) {')

new_func = """async function loadGabineteCards() {
            const activeList = document.getElementById('gabinete-active-list');

            try {
                // Pendentes
                db.collection('pastoral_tasks').where('status', '==', 'pendente').onSnapshot(snapP => {
                    const block = document.getElementById('diretrizes-block');
                    if(snapP.empty) {
                        if(block) block.style.display = 'none';
                        if(activeList) activeList.innerHTML = '';
                    } else {
                        if(block) block.style.display = 'block';
                        let htmlP = '';
                        snapP.forEach(doc => {
                            const d = doc.data();
                            const dateObj = d.criado_em ? d.criado_em.toDate() : new Date();
                            htmlP += `
                                <div style="background:#1e293b; border:1px solid #3b82f6; border-left:4px solid #3b82f6; border-radius:12px; padding:15px; margin-bottom:10px;">
                                    <div style="display:flex; justify-content:space-between; font-size:0.75rem; color:#94a3b8; margin-bottom:5px;">
                                        <span style="color:#60a5fa; font-weight:800;">${d.tipo}</span>
                                        <span>${dateObj.toLocaleDateString('pt-BR')}</span>
                                    </div>
                                    <div style="font-size:1rem; font-weight:800; color:#f8fafc; margin-bottom:5px;">${d.titulo}</div>
                                    <div style="font-size:0.85rem; color:#cbd5e1;">${d.descricao}</div>
                                </div>
                            `;
                        });
                        activeList.innerHTML = htmlP;
                    }
                });
            } catch(e) {
                console.error(e);
            }
        }

        """

content = content[:start] + new_func + content[end:]

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed loadGabineteCards")
