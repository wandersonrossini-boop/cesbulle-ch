import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. Update Bottom Nav (Mobile)
bottom_nav_pattern = r'<nav class="bottom-nav">.*?</nav>'
bottom_nav_replacement = '''<nav class="bottom-nav">
        <div class="nav-item active" onclick="switchCheckinMode('mural')">
            <span>Mural</span>
        </div>
        <div class="nav-item" onclick="switchCheckinMode('visitor')">
            <span>Visitantes</span>
        </div>
        <div class="nav-item" onclick="switchCheckinMode('child')">
            <span>Crianças</span>
        </div>
        <div class="nav-item" onclick="setTab('schedule')">
            <span>Agenda</span>
        </div>
        <div class="nav-item" onclick="setTab('events')">
            <span>Eventos</span>
        </div>
    </nav>'''
html = re.sub(bottom_nav_pattern, bottom_nav_replacement, html, flags=re.DOTALL)

# 2. Update Sidebar Nav (Desktop)
sidebar_nav_pattern = r'<div class="sidebar-nav">.*?</div>\s*<div class="sidebar-bottom">'
sidebar_nav_replacement = '''<div class="sidebar-nav">
            <div class="nav-link active" onclick="switchCheckinMode('mural', this)">Página principal</div>
            <div class="nav-link" onclick="switchCheckinMode('visitor', this)">Visitantes</div>
            <div class="nav-link" onclick="switchCheckinMode('child', this)">Crianças</div>
            <div class="nav-link" onclick="setTab('schedule')">Agenda</div>
            <div class="nav-link" onclick="setTab('events')">Eventos</div>
        </div>
        <div class="sidebar-bottom">'''
html = re.sub(sidebar_nav_pattern, sidebar_nav_replacement, html, flags=re.DOTALL)

# 3. Remove "INÍCIO" buttons
html = re.sub(r'<div onclick="window\.parent\.postMessage.*?&larr; IN.CIO</div>', '', html, flags=re.IGNORECASE)

# 4. Inject Mural Buttons
mural_buttons = '''<div style="display:flex; gap:10px; margin-bottom: 20px;">
                        <button onclick="setTab('live')" style="flex:1; padding:10px; border-radius:8px; border:1px solid var(--border-dark); background:var(--navy-main); color:var(--text-light); font-weight:600; cursor:pointer;"><i class="fas fa-bolt" style="color:var(--gold); margin-right:8px;"></i>Ações do Culto</button>
                        <button onclick="switchCheckinMode('online')" style="flex:1; padding:10px; border-radius:8px; border:1px solid var(--border-dark); background:var(--navy-main); color:var(--text-light); font-weight:600; cursor:pointer;"><i class="fas fa-qrcode" style="color:var(--gold); margin-right:8px;"></i>QR / Links</button>
                    </div>'''
html = re.sub(r'(<div id="mode-mural".*?<p.*?>.*?</p>)', r'\1\n' + mural_buttons, html, flags=re.DOTALL | re.IGNORECASE)

# 5. Hide old segmented control in checkin header so it doesn't conflict
html = re.sub(r'(<!-- === TAB 1: CHECK-IN === -->\s*<div id="tab-checkin" class="tab-section".*?)<div class="segmented-control">.*?</div>', r'\1', html, flags=re.DOTALL | re.IGNORECASE)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(html)
