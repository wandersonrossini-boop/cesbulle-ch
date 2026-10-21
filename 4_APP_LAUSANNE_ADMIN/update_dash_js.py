import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. We need to define loadEscalasDash() which will populate `proximo-culto-container` and `escalas-recentes-container`
# And add it to `iniciarGabinete()`
old_init = """        async function iniciarGabinete() {
            document.getElementById('loading-screen').style.display='none';
            document.getElementById('app-content').style.display='flex';
            
            loadKPIs();
            loadAtaDigitalFeed();
            loadGabineteCards();
            
            // Switch to dashboard tab
            switchPage('dashboard');
        }"""
        
new_init = """        async function iniciarGabinete() {
            document.getElementById('loading-screen').style.display='none';
            document.getElementById('app-content').style.display='flex';
            
            loadEscalasDash();
            loadAtaDigitalFeed();
            loadGabineteCards();
            
            // Switch to dashboard tab
            switchPage('dashboard');
        }"""
content = content.replace(old_init, new_init)

# 2. Modify loadGabineteCards to hide diretrizes-block if empty
old_gab_cards = """        async function loadGabineteCards() {
            const activeList = document.getElementById('gabinete-active-list');
            const historyList = document.getElementById('gabinete-history-list');

            try {
                // Pendentes
                db.collection('pastoral_tasks').where('status', '==', 'pendente').onSnapshot(snapP => {
                    if(snapP.empty) {
                        activeList.innerHTML = '<div style="text-align:center; padding:20px; color:#94a3b8; font-size:0.9rem;">Nenhuma diretriz pendente no momento.</div>';
                    } else {"""
                    
new_gab_cards = """        async function loadGabineteCards() {
            const activeList = document.getElementById('gabinete-active-list');

            try {
                // Pendentes
                db.collection('pastoral_tasks').where('status', '==', 'pendente').onSnapshot(snapP => {
                    const block = document.getElementById('diretrizes-block');
                    if(snapP.empty) {
                        if(block) block.style.display = 'none';
                        if(activeList) activeList.innerHTML = '';
                    } else {
                        if(block) block.style.display = 'block';"""
content = content.replace(old_gab_cards, new_gab_cards)

# 3. Add loadEscalasDash function before loadAtaDigitalFeed
new_func = """
        async function loadEscalasDash() {
            try {
                db.collection('escalas').orderBy('data', 'asc').onSnapshot(snap => {
                    const nextContainer = document.getElementById('proximo-culto-container');
                    const recentContainer = document.getElementById('escalas-recentes-container');
                    if(!nextContainer || !recentContainer) return;
                    
                    if(snap.empty) {
                        nextContainer.innerHTML = '<div style="color:var(--text-dim); padding:10px 0;">Nenhum culto agendado.</div>';
                        recentContainer.innerHTML = '<div style="color:var(--text-dim); padding:10px 0;">Nenhuma escala recente.</div>';
                        return;
                    }
                    
                    const now = new Date();
                    now.setHours(0,0,0,0);
                    
                    const todas = [];
                    snap.forEach(doc => {
                        const data = doc.data();
                        data.id = doc.id;
                        todas.push(data);
                    });
                    
                    const futuras = todas.filter(d => new Date(d.data + 'T00:00:00') >= now);
                    const proximas = futuras.slice(0, 1);
                    const recentes = todas.slice(0, 5); // Just show the top 5
                    
                    if(proximas.length > 0) {
                        const p = proximas[0];
                        const dObj = new Date(p.data + 'T00:00:00');
                        
                        nextContainer.innerHTML = `
                            <div style="font-size: 1.1rem; font-weight: 800; color: #fff; margin-bottom: 5px;">${p.nome_culto || 'Culto'}</div>
                            <div style="font-size: 0.9rem; color: var(--gold); font-weight: 700; margin-bottom: 10px;">${dObj.toLocaleDateString('pt-BR')} &middot; ${p.programacao && p.programacao[0] ? p.programacao[0].horario : '00:00'}</div>
                            <div style="font-size: 0.85rem; color: var(--text-dim);">
                                Dirigente: <span style="color:#CBD5E1;">${p.dirigente || 'Não informado'}</span><br>
                                Local: <span style="color:#CBD5E1;">${p.local || 'Sede'}</span>
                            </div>
                        `;
                    } else {
                        nextContainer.innerHTML = '<div style="color:var(--text-dim); padding:10px 0;">Nenhum culto futuro.</div>';
                    }
                    
                    let rHtml = '';
                    recentes.forEach(r => {
                        const dObj = new Date(r.data + 'T00:00:00');
                        rHtml += `
                            <div style="display:flex; justify-content:space-between; align-items:center; padding:10px 0; border-bottom:1px solid #1F2937;">
                                <div style="font-size:0.9rem; color:#fff; font-weight:600;">${r.nome_culto || 'Culto'}</div>
                                <div style="font-size:0.75rem; color:var(--text-dim);">${dObj.toLocaleDateString('pt-BR')}</div>
                            </div>
                        `;
                    });
                    recentContainer.innerHTML = rHtml;
                });
            } catch(e) {
                console.error(e);
            }
        }
"""
content = content.replace('async function loadAtaDigitalFeed()', new_func + '\n        async function loadAtaDigitalFeed()')

# Also, update loadAtaDigitalFeed layout to match the requested simple layout
old_ata = """                                html += `
                                    <div style="display:flex; gap:10px; margin-bottom:15px; align-items:flex-start;">
                                        <div style="background:rgba(255,255,255,0.05); padding:8px 12px; border-radius:8px; display:flex; flex-direction:column; align-items:center; min-width:60px;">
                                            <span style="font-size:0.75rem; color:var(--text-dim); text-transform:uppercase;">${hrStr}</span>
                                        </div>
                                        <div style="background:var(--navy-light); border:1px solid var(--border); padding:10px; border-radius:8px; flex:1;">
                                            <div style="font-size:0.85rem; font-weight:700; color:#fff;">${tStr}</div>
                                            <div style="font-size:0.8rem; color:var(--text-dim); margin-top:3px;">${descStr}</div>
                                        </div>
                                    </div>
                                `;"""
new_ata = """                                html += `
                                    <div style="display:flex; gap:15px; margin-bottom:10px; align-items:center;">
                                        <div style="font-size:0.85rem; color:var(--gold); font-weight:700; min-width:45px;">${hrStr}</div>
                                        <div style="font-size:0.9rem; color:#CBD5E1;">${tStr} - ${descStr}</div>
                                    </div>
                                `;"""
content = content.replace(old_ata, new_ata)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated JS for Dashboard in gabinete.html")
