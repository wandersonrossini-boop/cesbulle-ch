import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update topbar HTML
target_topbar = '''<div class="topbar">
            <div class="header-left">
                <div class="logo-box"><img src="assets/logo_3.png?v=70.3.79" alt="Logo"></div>
                <div class="clock-box">
                    <div id="clock">00:00</div>
                    <div id="timer-label">
                        <div class="live-dot"></div>
                        <span>Culto ao vivo</span>
                    </div>
                </div>
            </div>
            
            <div class="stats-row">'''

replacement_topbar = '''<div class="topbar">
            <div class="mobile-brand-bar" style="display: none; width: 100%; justify-content: space-between; align-items: flex-start; margin-bottom: 20px;">
                <div class="brand-text">
                    <h2 style="font-family: var(--font-serif); font-size: 1.15rem; color: #fff; margin: 0; line-height: 1.1;">CME<br>LAUSANNE</h2>
                    <div style="color: var(--gold); font-size: 0.65rem; font-weight: 700; letter-spacing: 1.5px; margin-top: 4px;">OPERAÇÃO</div>
                </div>
                <div onclick="document.getElementById('modal-mais').style.display='flex';" style="color: var(--gold); cursor: pointer; display: flex; flex-direction: column; align-items: center; gap: 4px;">
                    <span style="font-size: 0.75rem; font-weight: 700;">Mais</span>
                    <i class="fas fa-bars" style="font-size: 1.2rem;"></i>
                </div>
            </div>
            <div class="header-left">
                <div class="logo-box pc-only"><img src="assets/logo_3.png?v=70.3.79" alt="Logo"></div>
                <div class="clock-box">
                    <div id="clock">00:00</div>
                    <div id="timer-label">
                        <div class="live-dot"></div>
                        <span>Culto ao vivo</span>
                    </div>
                </div>
            </div>
            
            <div class="stats-row">'''

content = content.replace(target_topbar, replacement_topbar)

# 2. Add PC-only class to CSS
content = content.replace('/* HEADER */', '''/* HEADER */
        .pc-only { display: block; }
        @media (max-width: 900px) {
            .pc-only { display: none !important; }
            .mobile-brand-bar { display: flex !important; }
        }''')


with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Topbar updated")
