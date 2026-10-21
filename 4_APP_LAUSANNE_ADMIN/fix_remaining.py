import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Relatorios
content = re.sub(r'<div class="nav-item" onclick="switchPage\(\'relatorios\'\)" id="nav-relatorios">.*?</div>', '', content, flags=re.DOTALL)
content = re.sub(r'<div id="page-relatorios" class="page-content">.*?</div>\s*(<div id="page-settings")', r'\1', content, flags=re.DOTALL)

# 2. Update Ata Digital Text in HTML
content = content.replace('<h3 style="color:var(--gold); border-bottom:1px solid var(--border); padding-bottom:10px;"><i class="fas fa-history"></i> Ata Digital Completa</h3>', '<h3 style="color:var(--gold); border-bottom:1px solid var(--border); padding-bottom:10px;"><i class="fas fa-history"></i> Ata Digital</h3>')
content = content.replace('Histórico detalhado em tempo real de logs de recepção, decisões e eventos.', 'Registro das atividades realizadas no sistema.')
# Just in case encoding got messed up in previous scripts, let's also try to match the broken encoding:
content = content.replace('<h3 style="color:var(--gold); border-bottom:1px solid var(--border); padding-bottom:10px;"><i class="fas fa-history"></i> Ata Digital Completa</h3>'.replace('ó', '').replace('ç', '').replace('ã', '').replace('í', ''), '<h3 style="color:var(--gold); border-bottom:1px solid var(--border); padding-bottom:10px;"><i class="fas fa-history"></i> Ata Digital</h3>')

# Also handle "Histrico detalhado em tempo real..."
content = re.sub(r'Hist.*?rico detalhado em tempo real.*?\.', 'Registro das atividades realizadas no sistema.', content)


# 3. Fix Líderes HTML
content = content.replace('<th>E-mail</th>', '')
content = content.replace('<th>E-MAIL</th>', '')
content = content.replace('<td colspan="4"', '<td colspan="3"')

# 4. Fix loadPeopleList JS
pattern_lideres = re.compile(r'<td style="color:var\(--text-dim\);">\$\{l\.source \|\| \'Secretaria\'\}</td>\n', re.DOTALL)
content = re.sub(pattern_lideres, '', content)
# Check if there is another variation
content = content.replace("<td style=\"color:var(--text-dim);\">${l.source || 'Secretaria'}</td>", "")

# 5. Simplify Ata Digital Completa JS
old_ata_comp = """                        html += `
                            <div style="display:flex; gap:15px; margin-bottom:15px; background:#1e293b; padding:15px; border-radius:12px; border-left:3px solid ${color};">
                                <div style="min-width:70px; text-align:right;">
                                    <div style="font-size:0.75rem; color:#94a3b8; font-weight:800;">${dateObj.toLocaleDateString('pt-BR')}</div>
                                    <div style="font-size:0.7rem; color:#64748b;">${dateObj.toLocaleTimeString('pt-BR', {hour: '2-digit', minute:'2-digit'})}</div>
                                </div>
                                <div>
                                    <div style="font-size:0.8rem; color:${color}; font-weight:800; text-transform:uppercase; margin-bottom:3px;">${d.tipo}</div>
                                    <div style="font-size:0.95rem; color:#f8fafc;">${d.descricao}</div>
                                    <div style="font-size:0.75rem; color:#64748b; margin-top:4px;"><i class="fas fa-user-circle"></i> Resp: ${d.responsavel}</div>
                                </div>
                            </div>
                        `;"""

new_ata_comp = """                        // Simplify description
                        let shortDesc = d.descricao;
                        if(shortDesc.includes("foi registrado(a) pela primeira vez no sistema")) {
                            let nome = shortDesc.split(" foi ")[0];
                            nome = nome.charAt(0).toUpperCase() + nome.slice(1);
                            shortDesc = `${nome} entrou`;
                        } else if (shortDesc.includes("publicou uma nova escala")) {
                            let partes = shortDesc.split("nova escala de culto: ");
                            if (partes.length > 1) {
                                shortDesc = `Escala criada: ${partes[1].split(" para ")[0]}`;
                            }
                        }

                        let timeStr = dateObj.toLocaleTimeString('pt-BR', {hour: '2-digit', minute:'2-digit'});
                        let dateStr = dateObj.toLocaleDateString('pt-BR').substring(0,5);

                        html += `
                            <div style="padding:12px 0; border-bottom:1px solid rgba(255,255,255,0.03); display:flex; gap:15px; align-items:baseline;">
                                <div style="color:var(--text-dim); font-size:0.85rem; min-width:85px; font-variant-numeric: tabular-nums;">${dateStr} \u00b7 ${timeStr}</div>
                                <div style="font-size:0.9rem; color:#cbd5e1;">${shortDesc}</div>
                            </div>
                        `;"""

content = content.replace(old_ata_comp, new_ata_comp)


with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied fixes for Ata, Lideres, and Relatorios.")
