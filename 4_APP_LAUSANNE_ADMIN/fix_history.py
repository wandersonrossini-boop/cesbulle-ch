import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the Concluidas block entirely
old_concluidas = """                // Concluidas
                db.collection('pastoral_tasks').where('status', '==', 'concluido').orderBy('concluido_em', 'desc').limit(15).onSnapshot(snapC => {
                    if(snapC.empty) {
                        historyList.innerHTML = '<div style="text-align:center; padding:20px; color:#94a3b8; font-size:0.9rem;">O histrico est vazio.</div>';
                    } else {
                        let htmlC = '';
                        snapC.forEach(doc => {
                            const d = doc.data();
                            const dateObj = d.concluido_em ? d.concluido_em.toDate() : new Date();
                            htmlC += `
                                <div style="display:flex; justify-content:space-between; align-items:center; padding:10px 0; border-bottom:1px solid #334155;">
                                    <div>
                                        <div style="color:#94a3b8; font-size:0.85rem; text-decoration:line-through;">${d.titulo}</div>
                                        <div style="font-size:0.7rem; color:#64748b;">${d.tipo}  ${dateObj.toLocaleDateString('pt-BR')}</div>
                                    </div>
                                    <i class="fas fa-check-circle" style="color:#10b981;"></i>
                                </div>
                            `;
                        });
                        historyList.innerHTML = htmlC;
                    }
                });"""
content = content.replace(old_concluidas, "")

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed Concluidas block")
