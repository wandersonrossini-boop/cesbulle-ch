import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. We want `.header-left` to be flex-direction: column; align-items: flex-start; on mobile.
# Let's add that to the mobile media query.
mobile_css_addition = """
            .header-left { flex-direction: column; align-items: flex-start; gap: 8px; margin-bottom: 25px; }
            .time-display { font-size: 2rem; line-height: 1; }
            .topbar { margin-bottom: 15px; }
            .mobile-brand-bar { margin-bottom: 15px !important; }
            .container { padding: 15px 15px 0 15px; }
"""

# Insert into mobile media query
start = content.find('@media (max-width: 900px) {')
if start != -1:
    # find next bracket
    inner_start = content.find('{', start)
    content = content[:inner_start+1] + mobile_css_addition + content[inner_start+1:]

# 2. They asked to apply the "simple layout" logic to the Escala!
# "você me dá o sinal verde para voltarmos a refinar a Escala de Culto no Altar, aplicando essa mesma linguagem direta (foco no horário, atividade e equipe, sem enfeites)?"
# The user's response was "Sim." !
# Wait, let's look at the user prompt: "Sim. Tem que subir mais." 
# Oh, "Sim" was the answer to my question: "você me dá o sinal verde para voltarmos a refinar a Escala de Culto no Altar?"
# AND they added: "Tem que subir mais. Na tela que você mostrou..."
# So they approved BOTH! I should simplify Escala now!

# Let's redefine renderEscalaContent
old_render = """        function renderEscalaContent(escala, container) {
            const dateObj = new Date(escala.data + 'T00:00:00');
            const options = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
            const formattedDate = dateObj.toLocaleDateString('pt-BR', options);
            
            let programHtml = '';
            if(escala.programacao && escala.programacao.length > 0) {
                escala.programacao.forEach((item, index) => {
                    programHtml += `
                        <div style="display: flex; gap: 20px; position: relative; margin-bottom: 20px;">
                            ${index < escala.programacao.length - 1 ? `<div style="position: absolute; left: 15px; top: 35px; bottom: -25px; width: 2px; background: rgba(255,255,255,0.05);"></div>` : ''}
                            <div style="width: 32px; height: 32px; border-radius: 50%; background: var(--navy-light); border: 2px solid var(--border-color); display: flex; align-items: center; justify-content: center; color: var(--gold); font-weight: 700; font-size: 0.8rem; flex-shrink: 0; z-index: 1;">
                                ${index + 1}
                            </div>
                            <div style="background: var(--navy-light); border: 1px solid var(--border-color); border-radius: 8px; padding: 15px; flex: 1;">
                                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
                                    <div style="font-weight: 700; color: #fff; font-size: 1.05rem;">${item.horario} - ${item.atividade}</div>
                                </div>
                                ${item.responsavel ? `
                                <div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 0.9rem; background: rgba(0,0,0,0.2); padding: 8px 12px; border-radius: 6px;">
                                    <i class="fas fa-user-circle" style="color: var(--gold);"></i>
                                    <span>${item.responsavel}</span>
                                </div>
                                ` : ''}
                            </div>
                        </div>
                    `;
                });
            } else {
                programHtml = `<div style="color: var(--text-muted); font-style: italic;">Cronograma não detalhado.</div>`;
            }

            container.innerHTML = `
                <div style="margin-bottom: 25px; background: var(--navy-light); padding: 20px; border-radius: 8px; border: 1px solid var(--border-color);">
                    <div style="color: var(--gold); font-weight: 700; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 5px;">${formattedDate}</div>
                    <div style="font-size: 1.4rem; font-weight: 800; color: #fff; margin-bottom: 15px;">${escala.nome_culto}</div>
                    
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                        <div>
                            <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 3px;">Dirigente</div>
                            <div style="color: #fff; font-weight: 600;">${escala.dirigente || 'Não informado'}</div>
                        </div>
                        <div>
                            <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 3px;">Local</div>
                            <div style="color: #fff; font-weight: 600;">${escala.local || 'Sede'}</div>
                        </div>
                    </div>
                </div>

                <div style="font-weight: 700; color: #fff; margin-bottom: 20px; font-size: 1.1rem;">Cronograma do Culto</div>
                <div style="padding-left: 5px;">
                    ${programHtml}
                </div>
            `;
        }"""

new_render = """        function renderEscalaContent(escala, container) {
            let programHtml = '';
            if(escala.programacao && escala.programacao.length > 0) {
                escala.programacao.forEach((item) => {
                    programHtml += `
                        <div style="margin-bottom: 20px;">
                            <div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 4px;">
                                <div style="color: #fff; font-weight: 700; font-size: 1.1rem; min-width: 55px;">${item.horario}</div>
                                <div style="color: var(--gold); font-size: 1.1rem; font-weight: 800;">&middot;</div>
                                <div style="color: #fff; font-weight: 700; font-size: 1.1rem; text-transform: uppercase; letter-spacing: 0.5px;">${item.atividade}</div>
                            </div>
                            ${item.responsavel ? `
                            <div style="color: var(--text-muted); font-size: 0.95rem; padding-left: 75px; font-weight: 500;">
                                EQUIPE: <span style="color: #CBD5E1;">${item.responsavel}</span>
                            </div>
                            ` : ''}
                        </div>
                    `;
                });
            } else {
                programHtml = `<div style="color: var(--text-muted); font-style: italic;">Cronograma não detalhado.</div>`;
            }

            container.innerHTML = `
                <div style="padding-top: 10px;">
                    ${programHtml}
                </div>
            `;
        }"""

content = content.replace(old_render, new_render)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated altar_final.html mobile layout and Escala design")
