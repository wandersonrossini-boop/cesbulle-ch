import re

def align_to_image_model(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. Font links: Google Fonts Playfair Display & Inter
    fonts_link = '''<link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:wght@600;700&display=swap" rel="stylesheet">'''

    if 'fonts.googleapis.com/css2?family=Playfair+Display' not in html:
        html = html.replace('</head>', fonts_link + '\n</head>')

    # 2. Detailed CSS matching the uploaded image exactly
    css_model = '''
    <style>
        :root {
            --navy-dark: #0A131F;
            --navy-sidebar: #09121D;
            --navy-active: #192A3E;
            --gold-sub: #C9A96A;
            --blue-accent: #007AFF;
            --bg-body: #F8FAFC;
            --bg-card: #FFFFFF;
            --text-main: #0F172A;
            --text-muted: #64748B;
            --border-light: #E2E8F0;
            --font-serif: 'Playfair Display', Georgia, serif;
            --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        }

        body {
            background-color: var(--bg-body) !important;
            color: var(--text-main) !important;
            font-family: var(--font-sans) !important;
            margin: 0;
            padding: 0;
        }

        h1, h2, h3, h4, label, input, select, button, span, p, div {
            font-family: var(--font-sans);
        }

        .serif-title {
            font-family: var(--font-serif) !important;
        }

        /* App Layout */
        .app-layout {
            display: flex;
            min-height: 100vh;
        }

        /* Left Sidebar (PC) */
        .pc-sidebar {
            width: 240px;
            background: var(--navy-sidebar) !important;
            color: #FFFFFF;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 30px 0;
            border-right: 1px solid rgba(255, 255, 255, 0.05);
            flex-shrink: 0;
        }
        .sidebar-brand {
            padding: 0 28px 35px 28px;
        }
        .sidebar-brand h2 {
            font-family: var(--font-serif);
            font-size: 1.4rem;
            color: #FFFFFF;
            margin: 0;
            line-height: 1.2;
            font-weight: 700;
            letter-spacing: 0.5px;
        }
        .sidebar-brand .sub-brand {
            font-family: var(--font-sans);
            color: var(--gold-sub);
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 2px;
            margin-top: 4px;
            text-transform: uppercase;
        }

        .sidebar-nav {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .sidebar-nav .nav-link {
            padding: 14px 28px;
            color: #94A3B8;
            font-size: 0.95rem;
            font-weight: 500;
            text-decoration: none;
            display: flex;
            align-items: center;
            justify-content: space-between;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        .sidebar-nav .nav-link:hover {
            color: #FFFFFF;
        }
        .sidebar-nav .nav-link.active {
            background: var(--navy-active);
            color: #FFFFFF;
            font-weight: 600;
            position: relative;
        }
        .sidebar-nav .nav-link.active::after {
            content: '';
            position: absolute;
            right: 0;
            top: 50%;
            transform: translateY(-50%);
            border-top: 6px solid transparent;
            border-bottom: 6px solid transparent;
            border-right: 6px solid var(--bg-body);
        }

        .sidebar-bottom {
            padding: 0 28px;
        }
        .sidebar-bottom .logout-link {
            color: #64748B;
            font-size: 0.9rem;
            font-weight: 500;
            cursor: pointer;
        }

        /* Mobile Header */
        .mobile-header {
            display: none;
            background: var(--navy-sidebar);
            padding: 16px 20px;
            color: #FFFFFF;
            align-items: center;
            justify-content: space-between;
        }
        .mobile-header .brand-title {
            font-family: var(--font-serif);
            font-size: 1.15rem;
            font-weight: 700;
            margin: 0;
            color: #FFF;
        }
        .mobile-header .brand-sub {
            color: var(--gold-sub);
            font-size: 0.68rem;
            font-weight: 700;
            letter-spacing: 1.5px;
            text-transform: uppercase;
        }

        @media (max-width: 899px) {
            .pc-sidebar { display: none !important; }
            .mobile-header { display: flex !important; }
            .app-layout { flex-direction: column; }
        }

        /* Main App Area */
        .app-main {
            flex: 1;
            padding: 40px 48px;
            overflow-y: auto;
        }
        @media (max-width: 899px) {
            .app-main {
                padding: 24px 20px;
            }
        }

        /* Header Info Bar Top Right */
        .top-info-bar {
            display: flex;
            justify-content: flex-end;
            align-items: center;
            margin-bottom: 24px;
            gap: 15px;
            font-size: 0.82rem;
            color: #64748B;
        }
        .top-info-bar .date-str { font-weight: 500; }
        .top-info-bar .role-str { font-weight: 600; color: #475569; }

        /* Main Header Titles */
        .header-title-block {
            margin-bottom: 24px;
        }
        .header-title-block .section-label {
            font-size: 0.85rem;
            color: #64748B;
            font-weight: 500;
            margin: 0 0 2px 0;
        }
        .header-title-block .main-title {
            font-family: var(--font-serif);
            font-size: 2.2rem;
            font-weight: 700;
            color: #0F172A;
            margin: 0;
            letter-spacing: -0.5px;
        }

        /* Sub-tab Toggle (Novo visitante / Já visitou) */
        .visitor-subtabs {
            display: flex;
            gap: 32px;
            border-bottom: 1px solid var(--border-light);
            margin-bottom: 28px;
        }
        .subtab-btn {
            background: transparent;
            border: none;
            padding: 10px 0 14px 0;
            font-size: 0.95rem;
            font-weight: 600;
            color: #64748B;
            cursor: pointer;
            position: relative;
            transition: color 0.15s ease;
        }
        .subtab-btn.active {
            color: #0F172A;
        }
        .subtab-btn.active::after {
            content: '';
            position: absolute;
            bottom: -1px;
            left: 0;
            right: 0;
            height: 2px;
            background: var(--blue-accent);
        }

        /* Form Controls */
        .form-label {
            font-size: 0.88rem;
            font-weight: 700;
            color: #0F172A;
            margin-bottom: 8px;
            display: block;
        }

        .form-input {
            width: 100%;
            padding: 13px 16px;
            background: #F8FAFC !important;
            border: 1px solid var(--border-light) !important;
            border-radius: 6px !important;
            font-size: 0.95rem !important;
            color: #0F172A !important;
            box-sizing: border-box;
            margin-bottom: 20px !important;
            outline: none;
            transition: border-color 0.15s ease;
        }
        .form-input:focus {
            border-color: var(--navy-dark) !important;
            background: #FFFFFF !important;
        }

        .phone-group {
            display: flex;
            gap: 12px;
            margin-bottom: 24px;
        }
        .ddi-select {
            width: 90px;
            padding: 13px 12px;
            background: #F8FAFC !important;
            border: 1px solid var(--border-light) !important;
            border-radius: 6px !important;
            font-size: 0.95rem !important;
            font-weight: 600;
            color: #0F172A !important;
            outline: none;
        }

        /* Submit Button with Enter Badge */
        .submit-btn-container {
            width: 100%;
            background: var(--navy-dark);
            color: #FFFFFF;
            border: none;
            border-radius: 6px;
            padding: 14px 20px;
            font-size: 0.98rem;
            font-weight: 600;
            display: flex;
            justify-content: space-between;
            align-align: center;
            align-items: center;
            cursor: pointer;
            transition: background 0.15s ease;
            box-sizing: border-box;
            margin-bottom: 18px;
        }
        .submit-btn-container:hover {
            background: var(--navy-active);
        }
        .submit-btn-container .btn-text {
            flex: 1;
            text-align: center;
            padding-left: 30px;
        }
        .submit-btn-container .enter-badge {
            background: #192A3E;
            color: #94A3B8;
            font-size: 0.75rem;
            font-weight: 500;
            padding: 4px 10px;
            border-radius: 4px;
        }

        /* Drawer Toggle Link */
        .drawer-toggle-link {
            font-size: 0.85rem;
            font-weight: 500;
            color: #475569;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 6px;
            user-select: none;
        }

        /* Layout Grid PC */
        .pc-main-grid {
            display: grid;
            grid-template-columns: 1fr 380px;
            gap: 40px;
        }
        @media (max-width: 1024px) {
            .pc-main-grid {
                grid-template-columns: 1fr;
            }
        }

        /* Right Column Card: Últimas Entradas */
        .latest-entries-card {
            background: #FFFFFF;
            border: 1px solid var(--border-light);
            border-radius: 8px;
            padding: 20px;
        }
        .latest-entries-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
        }
        .latest-entries-header h3 {
            font-size: 1rem;
            font-weight: 700;
            color: #0F172A;
            margin: 0;
        }
        .latest-entries-header .view-all {
            font-size: 0.82rem;
            font-weight: 600;
            color: var(--blue-accent);
            text-decoration: none;
            cursor: pointer;
        }

        .entry-row {
            display: flex;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid #F1F5F9;
            font-size: 0.88rem;
        }
        .entry-row:last-child {
            border-bottom: none;
        }
        .entry-row .time {
            width: 55px;
            color: #64748B;
            font-size: 0.82rem;
            font-weight: 500;
        }
        .entry-row .name {
            flex: 1;
            font-weight: 600;
            color: #0F172A;
        }
        .entry-row .badge-visitante {
            background: #E2E8F0;
            color: #475569;
            font-size: 0.75rem;
            font-weight: 600;
            padding: 3px 10px;
            border-radius: 4px;
        }
        .entry-row .badge-membro {
            background: #D1FAE5;
            color: #065F46;
            font-size: 0.75rem;
            font-weight: 600;
            padding: 3px 10px;
            border-radius: 4px;
        }

        /* 4 Lower Access Cards */
        .four-cards-row {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 16px;
            margin-top: 40px;
        }
        @media (max-width: 600px) {
            .four-cards-row {
                grid-template-columns: repeat(2, 1fr);
            }
        }
        .access-card-single {
            background: #FFFFFF;
            border: 1px solid var(--border-light);
            border-radius: 6px;
            padding: 24px 16px;
            text-align: left;
            position: relative;
            cursor: pointer;
            transition: border-color 0.15s ease;
        }
        .access-card-single::before {
            content: '';
            position: absolute;
            top: 0;
            left: 20px;
            width: 36px;
            height: 3px;
            background: var(--blue-accent);
            border-radius: 0 0 2px 2px;
        }
        .access-card-single:hover {
            border-color: #CBD5E1;
        }
        .access-card-single h4 {
            font-size: 1rem;
            font-weight: 700;
            color: #0F172A;
            margin: 0;
        }
    </style>
'''

    if '</head>' in html:
        html = html.replace('</head>', css_model + '\n</head>')

    # 3. Replace Sidebar Structure on Left (PC)
    sidebar_html = '''    <aside class="pc-sidebar">
        <div class="sidebar-brand">
            <h2>CME<br>LAUSANNE</h2>
            <div class="sub-brand">RECEPÇÃO</div>
        </div>
        <div class="sidebar-nav">
            <div class="nav-link active" onclick="switchCheckinMode('visitor', this)">Visitante</div>
            <div class="nav-link" onclick="switchCheckinMode('child', this)">Criança</div>
            <div class="nav-link" onclick="setTab('events')">Eventos</div>
            <div class="nav-link" onclick="switchCheckinMode('online', this)">Online / QR</div>
            <div class="nav-link" onclick="switchCheckinMode('mural', this)">Mural</div>
        </div>
        <div class="sidebar-bottom">
            <div class="logout-link" onclick="if(typeof AuthManager!=='undefined')AuthManager.logout();">Sair</div>
        </div>
    </aside>'''

    html = re.sub(r'<aside class="pc-sidebar">.*?</aside>', sidebar_html, html, flags=re.DOTALL)

    # 4. Mobile Header
    mobile_header_html = '''    <div class="mobile-header">
        <div>
            <h2 class="brand-title">CME LAUSANNE</h2>
            <div class="brand-sub">RECEPÇÃO</div>
        </div>
        <div style="font-size: 1.2rem; cursor: pointer;" onclick="document.querySelector('.sidebar-nav').classList.toggle('show-mobile')">☰</div>
    </div>'''

    if '<div class="mobile-header">' not in html:
        html = html.replace('<div class="app-layout">', mobile_header_html + '\n    <div class="app-layout">')

    # 5. Top Right Date/Role Bar & Main Title
    header_titles_html = '''
    <div class="top-info-bar">
        <span class="date-str" id="live-date-str">Domingo, 21 de setembro de 2025 10:24</span>
        <span class="role-str">Equipe de Recepção</span>
    </div>

    <div class="header-title-block">
        <div class="section-label">Recepção</div>
        <h1 class="main-title">Visitante</h1>
    </div>

    <script>
        (function() {
            function updateLiveDate() {
                const el = document.getElementById('live-date-str');
                if(!el) return;
                const now = new Date();
                const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' };
                let str = now.toLocaleDateString('pt-BR', options);
                str = str.charAt(0).toUpperCase() + str.slice(1);
                el.innerText = str.replace('-feira', '');
            }
            updateLiveDate();
            setInterval(updateLiveDate, 60000);
        })();
    </script>
    '''

    # Replace old header titles inside #tab-checkin
    html = re.sub(r'<div style="margin-bottom: 20px;">\s*<p class="page-subtitle-top">.*?</p>\s*<h1 class="page-title">.*?</h1>\s*</div>', header_titles_html, html, flags=re.DOTALL)

    # 6. Visitor Sub-tabs (Novo visitante / Já visitou)
    subtabs_html = '''
    <div class="visitor-subtabs">
        <button class="subtab-btn active" id="btn-subtab-new" onclick="switchVisitorSubMode('new', this)">Novo visitante</button>
        <button class="subtab-btn" id="btn-subtab-exist" onclick="switchVisitorSubMode('exist', this)">Já visitou</button>
    </div>
    '''

    # Replace existing inner segmented control for visitor
    html = re.sub(r'<div class="segmented-control"[^>]*>\s*<button[^>]*>NOVO.*?</button>\s*<button[^>]*>JÁ VISITOU.*?</button>\s*</div>', subtabs_html, html, flags=re.DOTALL)

    # 7. Visitor Form Layout
    # Submit button with Enter badge
    submit_btn_html = '''
    <button onclick="submitVisitor()" class="submit-btn-container" id="btn-submit-visitor">
        <span class="btn-text">Registrar entrada</span>
        <span class="enter-badge">Enter</span>
    </button>
    '''
    html = re.sub(r'<button onclick="submitVisitor\(\)" class="btn-large btn-gold".*?</button>', submit_btn_html, html, flags=re.DOTALL)

    # 8. Four Lower Access Cards (Criança, Eventos, Online / QR, Mural)
    four_cards_html = '''
    <div class="four-cards-row">
        <div class="access-card-single" onclick="switchCheckinMode('child', this)">
            <h4>Criança</h4>
        </div>
        <div class="access-card-single" onclick="setTab('events')">
            <h4>Eventos</h4>
        </div>
        <div class="access-card-single" onclick="switchCheckinMode('online', this)">
            <h4>Online / QR</h4>
        </div>
        <div class="access-card-single" onclick="switchCheckinMode('mural', this)">
            <h4>Mural</h4>
        </div>
    </div>
    '''

    html = re.sub(r'<div class="four-access-grid">.*?</div>\s*</div>', four_cards_html, html, flags=re.DOTALL)

    # Write back to file
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)

    print("Aligned precisely to reference model image.")

align_to_image_model('recepcao_v2.html')
