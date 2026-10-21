import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

target_fn = '        function renderEscalaContent(escala, container) {'
end_fn = '                container.innerHTML = html;\n            }, 50);\n        }'
start_idx = content.find(target_fn)
end_idx = content.find(end_fn, start_idx) + len(end_fn)
original_fn = content[start_idx:end_idx]

new_fn = r'''        function renderEscalaContent(escala, container) {
            const dateObj = new Date(escala.data + 'T00:00:00');
            const options = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
            const formattedDate = dateObj.toLocaleDateString('pt-BR', options);
            
            let programHtml = '';
            if(escala.programacao && escala.programacao.length > 0) {
                escala.programacao.forEach(item => {
                    programHtml += `
                        <div style="display: flex; gap: 15px; margin-bottom: 25px; align-items: flex-start;">
                            <div style="font-size: 1rem; font-weight: 700; color: var(--gold); min-width: 55px; padding-top: 1px;">
                                ${item.horario}
                            </div>
                            <div style="flex: 1;">
                                <div style="font-size: 1.1rem; font-weight: 600; color: #ffffff;">${item.atividade}</div>
                                ${item.responsavel ? `<div style="font-size: 0.95rem; color: #cbd5e1; margin-top: 4px;">${item.responsavel}</div>` : ''}
                            </div>
                        </div>
                    `;
                });
            } else {
                programHtml = `<div style="color: #94A3B8; padding: 10px 0;">Nenhuma atividade listada.</div>`;
            }
            
            const part = escala.participantes || {};
            let participantsHtml = '';
            const teams = [
                { name: 'Louvor', val: part.louvor },
                { name: 'Mídia', val: part.midia },
                { name: 'Recepção', val: part.recepcao },
                { name: 'Kids', val: part.kids },
                { name: 'Intercessão', val: part.intercessao }
            ].filter(t => t.val && t.val.trim() !== '');
            
            if(teams.length > 0) {
                participantsHtml = `
                    <div style="margin-top: 40px;">
                        <div style="font-size: 0.85rem; font-weight: 700; letter-spacing: 1.5px; color: var(--gold); text-transform: uppercase; margin-bottom: 20px;">Equipes de Apoio</div>
                        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 20px;">
                            ${teams.map(t => `
                                <div>
                                    <div style="font-size: 0.75rem; color: #64748b; text-transform: uppercase; font-weight: 700; letter-spacing: 1px;">${t.name}</div>
                                    <div style="font-size: 0.95rem; color: #e2e8f0; margin-top: 4px;">${t.val}</div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                `;
            }

            container.style.opacity = 0;
            setTimeout(() => {
                const html = `
                    <div style="padding: 10px 10px 40px 10px;">
                        <h2 style="font-family: var(--font-heading); font-size: 1.8rem; font-weight: 600; color: #fff; margin-bottom: 8px; line-height: 1.1; text-transform: uppercase;">${escala.nome_culto}</h2>
                        <div style="font-size: 1rem; color: #cbd5e1; margin-bottom: 25px; line-height: 1.5;">
                            ${formattedDate} &middot; ${escala.horario_inicio}H<br>
                            ${escala.dirigente ? `${escala.dirigente} &middot; ` : ''}${escala.local || 'Lausanne'}
                        </div>
                        
                        <div style="height: 1px; background: rgba(255,255,255,0.1); margin-bottom: 25px;"></div>
                        
                        <div style="font-size: 0.85rem; font-weight: 700; letter-spacing: 1.5px; color: var(--gold); text-transform: uppercase; margin-bottom: 25px;">Cronograma</div>
                        
                        ${programHtml}
                        
                        ${participantsHtml}
                    </div>
                `;
                container.innerHTML = html;
                container.style.opacity = 1;
            }, 50);
        }'''

content = content.replace(original_fn, new_fn)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("renderEscalaContent updated successfully")
