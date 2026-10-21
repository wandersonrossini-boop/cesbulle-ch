import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Clean loadDiretrizesPage Active
old_dir_ativas = """                                <div style="background:#1e293b; border:1px solid #3b82f6; border-left:4px solid #3b82f6; border-radius:12px; padding:15px; margin-bottom:12px;">
                                    <div style="display:flex; justify-content:space-between; font-size:0.75rem; color:#94a3b8; margin-bottom:5px;">
                                        <span style="color:#60a5fa; font-weight:800;">${d.tipo}</span>
                                        <span>${dateObj.toLocaleDateString('pt-BR')}</span>
                                    </div>
                                    <div style="font-size:1rem; font-weight:800; color:#f8fafc; margin-bottom:5px;">${d.titulo}</div>
                                    <div style="font-size:0.85rem; color:#cbd5e1; margin-bottom:10px;">${d.descricao}</div>
                                    <div style="display:flex; justify-content:flex-end;">
                                        <button onclick="concluirDiretriz('${doc.id}')" style="background:#10b981; border:none; color:#000; padding:6px 12px; border-radius:6px; font-weight:800; font-size:0.8rem; cursor:pointer;"><i class="fas fa-check"></i> Marcar Concluída</button>
                                    </div>
                                </div>"""
old_dir_ativas_alt = old_dir_ativas.replace("Concluída", "Concluda")

new_dir_ativas = """                                <div style="padding:15px 0; border-bottom:1px solid rgba(255,255,255,0.05); margin-bottom:12px;">
                                    <div style="font-size:1rem; font-weight:800; color:#f8fafc; margin-bottom:5px;">${d.titulo}</div>
                                    <div style="font-size:0.85rem; color:#cbd5e1; margin-bottom:10px;">${d.descricao}</div>
                                    <div style="display:flex; justify-content:space-between; align-items:center;">
                                        <span style="font-size:0.75rem; color:var(--text-dim);">${d.tipo} &middot; ${dateObj.toLocaleDateString('pt-BR')}</span>
                                        <button onclick="concluirDiretriz('${doc.id}')" style="background:transparent; border:1px solid rgba(255,255,255,0.2); color:#f8fafc; padding:6px 12px; border-radius:4px; font-weight:600; font-size:0.8rem; cursor:pointer;">Concluir</button>
                                    </div>
                                </div>"""
content = content.replace(old_dir_ativas, new_dir_ativas)
content = content.replace(old_dir_ativas_alt, new_dir_ativas)


# 2. Clean loadDiretrizesPage Completed
old_dir_conc = """                                <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border); border-radius:12px; padding:12px; margin-bottom:10px; display:flex; justify-content:space-between; align-items:center;">
                                    <div>
                                        <div style="font-weight:600; color:#cbd5e1; font-size:0.85rem; text-decoration:line-through;">${d.titulo}</div>
                                        <div style="font-size:0.7rem; color:var(--text-dim); margin-top:3px;">${d.tipo} · Concluída em ${dateObj.toLocaleDateString('pt-BR')}</div>
                                    </div>
                                    <i class="fas fa-check-circle" style="color:#10b981; font-size:1.1rem;"></i>
                                </div>"""
old_dir_conc_alt = old_dir_conc.replace("Concluída", "Concluda").replace("·", "")

new_dir_conc = """                                <div style="padding:12px 0; border-bottom:1px solid rgba(255,255,255,0.05); margin-bottom:10px;">
                                    <div style="font-weight:600; color:#cbd5e1; font-size:0.9rem;">${d.titulo}</div>
                                    <div style="font-size:0.8rem; color:var(--text-dim); margin-top:3px;">${d.tipo} &middot; Concluída em ${dateObj.toLocaleDateString('pt-BR')}</div>
                                </div>"""
content = content.replace(old_dir_conc, new_dir_conc)
content = content.replace(old_dir_conc_alt, new_dir_conc)


# 3. Clean loadOrdensPage
old_ordens = """                        <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border); border-left:4px solid ${badgeColor}; border-radius:12px; padding:15px; margin-bottom:12px;">
                            <div style="display:flex; justify-content:space-between; font-size:0.75rem; color:#94a3b8; margin-bottom:5px;">
                                <span style="font-weight:800; color:${badgeColor};">${d.tipo}</span>
                                <span>${dateObj.toLocaleDateString('pt-BR')}</span>
                            </div>
                            <div style="font-size:1rem; font-weight:800; color:#f8fafc; margin-bottom:5px;">${d.titulo}</div>
                            <div style="font-size:0.85rem; color:#cbd5e1;">${d.descricao}</div>
                            <div style="margin-top:10px; display:flex; justify-content:space-between; align-items:center; font-size:0.75rem; color:var(--text-dim);">
                                <span>Status: <strong style="color:${badgeColor};">${d.status.toUpperCase()}</strong></span>
                                ${d.status === 'pendente' ? `<button onclick="concluirDiretriz('${doc.id}')" style="background:#10b981; border:none; color:#000; padding:4px 10px; border-radius:4px; font-weight:800; font-size:0.7rem; cursor:pointer;"><i class="fas fa-check"></i> Concluir</button>` : ''}
                            </div>
                        </div>"""

new_ordens = """                        <div style="padding:15px 0; border-bottom:1px solid rgba(255,255,255,0.05); margin-bottom:12px;">
                            <div style="font-size:1rem; font-weight:800; color:#f8fafc; margin-bottom:5px;">${d.titulo}</div>
                            <div style="font-size:0.85rem; color:#cbd5e1; margin-bottom:10px;">${d.descricao}</div>
                            <div style="margin-top:10px; display:flex; justify-content:space-between; align-items:center; font-size:0.75rem; color:var(--text-dim);">
                                <span>${d.tipo} &middot; ${dateObj.toLocaleDateString('pt-BR')} &middot; Status: <strong>${d.status}</strong></span>
                                ${d.status === 'pendente' ? `<button onclick="concluirDiretriz('${doc.id}')" style="background:transparent; border:1px solid rgba(255,255,255,0.2); color:#f8fafc; padding:6px 12px; border-radius:4px; font-weight:600; font-size:0.8rem; cursor:pointer;">Concluir</button>` : ''}
                            </div>
                        </div>"""
content = content.replace(old_ordens, new_ordens)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied JS dynamic generation UI strip.")
