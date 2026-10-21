import re

with open('kids.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. We don't need a massive CSS overhaul, just update the presence list rendering and CSS.
new_css = '''
        /* PRESENCE LIST */
        .presence-container { margin-top: 50px; }
        .presence-header { display: flex; align-items: center; gap: 8px; padding-bottom: 20px; cursor: pointer; }
        .presence-title { font-size: 0.95rem; font-weight: 700; color: var(--text-dark); text-transform: uppercase; letter-spacing: 1px; }
        
        .presence-card {
            background: #ffffff;
            border: 1px solid var(--border-line);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 15px;
            box-shadow: 0 2px 5px rgba(15, 23, 42, 0.03);
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        .presence-card-header {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .presence-card-name {
            font-size: 1.15rem;
            font-weight: 700;
            color: var(--text-dark);
        }
        .presence-card-age {
            font-size: 0.9rem;
            color: var(--text-muted);
            font-weight: 500;
        }
        .presence-card-footer {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-top: 1px solid var(--border-line);
            padding-top: 12px;
            margin-top: 5px;
        }
        .presence-status {
            font-size: 0.85rem;
            color: #10B981; /* Emerald green for active */
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .presence-status::before {
            content: '';
            display: block;
            width: 6px;
            height: 6px;
            background: #10B981;
            border-radius: 50%;
        }
        .btn-checkout {
            background: transparent;
            border: none;
            color: var(--text-muted);
            font-size: 0.85rem;
            font-weight: 600;
            cursor: pointer;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            transition: color 0.2s;
        }
        .btn-checkout:hover { color: #ef4444; }
'''

# Find PRESENCE LIST CSS block and replace it
start_css = content.find('/* PRESENCE LIST */')
end_css = content.find('</style>')
content = content[:start_css] + new_css + content[end_css:]

# 2. Update HTML
old_html = '''        <div class="presence-container">
            <div class="presence-header" onclick="togglePresenceList()">
                <div class="presence-title">PRESENÇAS HOJE</div>
                <div class="presence-count" id="kids-count-active">0</div>
            </div>
            
            <div id="presence-list-content" style="display:none;">
                <div id="kids-list-active"></div>
                <div style="display: flex; justify-content: flex-end; margin-top: 30px;">
                    <button onclick="endKidsSession()" style="background:transparent; border:none; color:#ef4444; font-weight:600; cursor:pointer; text-transform:uppercase; font-size: 0.8rem; letter-spacing: 1px;">
                        Encerrar Sala
                    </button>
                </div>
            </div>
        </div>'''

new_html = '''        <div class="presence-container">
            <div class="presence-header" onclick="togglePresenceList()">
                <div class="presence-title" id="presence-header-title">PRESENÇAS HOJE &middot; 0</div>
            </div>
            
            <div id="presence-list-content" style="display:none;">
                <div id="kids-list-active"></div>
                <div style="display: flex; justify-content: center; margin-top: 30px; border-top: 1px solid var(--border-line); padding-top: 25px;">
                    <button onclick="endKidsSession()" style="background:transparent; border:none; color:#ef4444; font-weight:600; cursor:pointer; text-transform:uppercase; font-size: 0.75rem; letter-spacing: 1px; opacity: 0.7;">
                        Encerrar Todos
                    </button>
                </div>
            </div>
        </div>'''

content = content.replace(old_html, new_html)

# 3. Update JS rendering
old_js_update = '''            document.getElementById('kids-count-active').innerText = active.length;
            active.forEach((d, i) => {
                const item = document.createElement('div');
                item.className = 'presence-item';
                item.innerHTML = `<div class="presence-name">${d.name}</div><div class="presence-age">${d.age_group || ''}</div>`;
                listActive.appendChild(item);
            });'''

new_js_update = '''            document.getElementById('presence-header-title').innerHTML = `PRESENÇAS HOJE &middot; ${active.length}`;
            active.forEach((d, i) => {
                const item = document.createElement('div');
                item.className = 'presence-card';
                item.innerHTML = `
                    <div class="presence-card-header">
                        <div class="presence-card-name">${d.name}</div>
                        <div class="presence-card-age">${d.age_group || ''}</div>
                    </div>
                    <div class="presence-card-footer">
                        <div class="presence-status">Sala ativa</div>
                        <button class="btn-checkout" onclick="checkoutKid('${d.id}', '${d.name}')">Encerrar</button>
                    </div>
                `;
                listActive.appendChild(item);
            });'''

content = content.replace(old_js_update, new_js_update)

# 4. Add checkoutKid function
js_funcs = '''        function endKidsSession() {'''
new_js_funcs = '''        function checkoutKid(id, name) {
            if(confirm(`Deseja encerrar a presença de ${name}?`)) {
                updateStatus(id, 'finished');
            }
        }

        function endKidsSession() {'''
content = content.replace(js_funcs, new_js_funcs)

with open('kids.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated presence list in kids.html")
