import sys

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. Add CSS for sidebar and layout
    css_patch = '''
        /* --- DESKTOP / PC RESPONSIVE ADAPTATIONS (min-width: 900px) --- */
        @media (min-width: 900px) {
            .app-layout {
                display: flex;
                min-height: 100vh;
                width: 100%;
                background: var(--bg-light-page);
            }
            .pc-sidebar {
                display: flex !important;
                flex-direction: column;
                width: 250px;
                background: var(--bg-dark-sidebar);
                color: #ffffff;
                border-right: 1px solid var(--border-dark);
                padding: 30px 20px;
                height: 100vh;
                position: sticky;
                top: 0;
            }
            .sidebar-header { margin-bottom: 40px; padding-left: 10px; }
            .sidebar-header h2 { font-family: var(--font-serif); font-size: 1.5rem; margin: 0; letter-spacing: 1px; color: #fff;}
            .sidebar-header h2 span { color: var(--gold); }
            
            .sidebar-menu { display: flex; flex-direction: column; gap: 8px; }
            .sidebar-menu .segment-btn {
                background: transparent;
                color: rgba(255, 255, 255, 0.7);
                text-align: left;
                padding: 14px 18px;
                border-radius: 10px;
                font-size: 0.95rem;
                font-weight: 500;
                display: flex;
                align-items: center;
                gap: 12px;
                transition: all 0.2s ease;
                text-transform: none;
                letter-spacing: normal;
                border: none;
                cursor: pointer;
            }
            .sidebar-menu .segment-btn:hover { background: rgba(255, 255, 255, 0.05); color: #fff; }
            .sidebar-menu .segment-btn.active {
                background: rgba(158, 121, 62, 0.15) !important;
                color: var(--gold) !important;
                font-weight: 700;
                border-left: 3px solid var(--gold);
                border-radius: 0 10px 10px 0;
            }
            .sidebar-menu i { font-size: 1.2rem; width: 24px; text-align: center; }

            .app-main { flex: 1; overflow-y: auto; padding: 0; }
            
            #tab-checkin > .segmented-control { display: none !important; }
            .bottom-nav { display: none !important; }
            #tab-checkin > div:first-child { display: none !important; } /* Hide Bem-vindo text on PC */
            
            body { padding-bottom: 0 !important; padding-top: 0 !important; }
            .container { max-width: 1400px !important; margin: 0 !important; padding: 40px 50px !important; }
            
            .pc-column-right { display: flex; flex-direction: column; gap: 30px; }
        }
        .pc-sidebar { display: none; }
'''
    if '/* --- DESKTOP / PC RESPONSIVE ADAPTATIONS (min-width: 900px) --- */' in html:
        html = html.split('/* --- DESKTOP / PC RESPONSIVE ADAPTATIONS (min-width: 900px) --- */')[0] + css_patch + '</style>' + html.split('</style>', 1)[1]

    # 2. Add Layout HTML
    layout_start = '''<div class="app-layout">
    <aside class="pc-sidebar">
        <div class="sidebar-header">
            <h2><span>ES</span> LAUSANNE</h2>
        </div>
        <div class="sidebar-menu">
            <button class="segment-btn active" onclick="switchCheckinMode('visitor', this)"><i class="fas fa-user"></i> Visitante</button>
            <button class="segment-btn" onclick="switchCheckinMode('child', this)"><i class="fas fa-child"></i> Criança</button>
            <button class="segment-btn" onclick="switchCheckinMode('online', this)"><i class="fas fa-qrcode"></i> Online / QR</button>
            <button class="segment-btn" onclick="switchCheckinMode('mural', this)"><i class="fas fa-list-check"></i> Mural Kids</button>
            <hr style="border:0; border-top:1px solid rgba(255,255,255,0.1); margin:15px 0; width: 100%;">
            <button class="segment-btn" onclick="setTab('events')"><i class="fas fa-calendar-check"></i> Eventos</button>
        </div>
    </aside>
    <main class="app-main">
'''
    if '<div class="app-layout">' not in html:
        html = html.replace('<div class="container" style="padding-bottom: 150px;">', layout_start + '<div class="container" style="padding-bottom: 150px;">')
        html = html.replace('<!-- TOAST CONTAINER -->', '</main></div>\n\n    <!-- TOAST CONTAINER -->')

    # 3. Add Últimas Entradas
    ultimas_entradas = '''
        <!-- LATEST ENTRIES MODULE -->
        <div class="ultimas-entradas-container" style="margin-top: 5px;">
            <div style="display: flex; align-items: center; margin-bottom: 15px;">
                <div style="width: 40px; height: 40px; border-radius: 50%; background: rgba(16, 185, 129, 0.1); display: flex; align-items: center; justify-content: center; margin-right: 12px;">
                    <i class="fas fa-history" style="color: #10b981; font-size: 1.1rem;"></i>
                </div>
                <div>
                    <h3 class="title-modern" style="color:var(--primary); margin:0; font-size: 1.3rem;">Últimas Entradas</h3>
                    <p style="color:#666; font-size:0.8rem; margin:2px 0 0 0;">Visitantes registrados hoje.</p>
                </div>
            </div>
            <div id="latest-visitors-list" style="display:flex; flex-direction:column; gap:10px; max-height: 400px; overflow-y:auto; padding-right: 5px;">
                <div style="color:#aaa; text-align:center; padding:10px; font-style: italic; font-size: 0.9rem;">
                    Aguardando atualizações...
                </div>
            </div>
            
            <script>
                // Listen to latest visitors from attendance (today)
                window.addEventListener('load', () => {
                    const container = document.getElementById('latest-visitors-list');
                    if(window.db) {
                        const todayStart = new Date();
                        todayStart.setHours(0,0,0,0);
                        db.collection('attendance')
                          .where('timestamp', '>=', firebase.firestore.Timestamp.fromDate(todayStart))
                          .onSnapshot(snap => {
                              const docs = snap.docs.map(d => ({id: d.id, ...d.data()}))
                                           .filter(d => d.type === 'visitante' || d.type === 'visitante_existente' || (d.type && d.type.toLowerCase().includes('visitante')));
                              
                              docs.sort((a,b) => (b.timestamp?.seconds || 0) - (a.timestamp?.seconds || 0));
                              
                              if(docs.length === 0) {
                                  container.innerHTML = '<div style="color:#aaa; text-align:center; padding:10px; font-style: italic; font-size: 0.9rem;">Nenhum visitante registrado hoje.</div>';
                                  return;
                              }
                              
                              container.innerHTML = docs.slice(0, 15).map(d => `
                                  <div style="background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 15px; display: flex; align-items: center; gap: 12px;">
                                      <div style="width:36px; height:36px; border-radius:50%; background:#f1f5f9; color:#64748b; display:flex; justify-content:center; align-items:center; font-weight:700; font-size:0.9rem;">
                                          ${d.name ? d.name.charAt(0).toUpperCase() : '?'}
                                      </div>
                                      <div style="flex: 1;">
                                          <div style="font-weight: 700; color: #1e293b; font-size: 0.95rem;">${d.name}</div>
                                          <div style="color: #64748b; font-size: 0.75rem;">${d.detail || 'Visitante'}</div>
                                      </div>
                                      <div style="font-size: 0.75rem; color: #94a3b8; white-space: nowrap;">
                                          ${d.timestamp ? new Date(d.timestamp.toDate()).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 'Agora'}
                                      </div>
                                  </div>
                              `).join('');
                          });
                    }
                });
            </script>
        </div>
'''
    if '<!-- LATEST ENTRIES MODULE -->' not in html:
        html = html.replace('</div> <!-- END visitor-sub-exist -->', '</div> <!-- END visitor-sub-exist -->\n' + ultimas_entradas)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Patched successfully")

patch_file('recepcao_v2.html')
