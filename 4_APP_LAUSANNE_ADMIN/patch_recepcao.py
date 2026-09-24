import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace ES LAUSANNE with CME LAUSANNE
content = content.replace('ES LAUSANNE', 'CME LAUSANNE')

# Inject dark theme CSS before </head>
dark_theme = '''
    <style>
        /* INJECTED DARK THEME */
        :root {
            --navy-main: #0A131F !important;
            --navy-card: #0F172A !important;
            --navy-hover: #14263D !important;
            --gold-main: #C9A96A !important;
            --text-light: #F8FAFC !important;
            --text-muted: #94A3B8 !important;
            --border-dark: #1E293B !important;
        }
        
        body, .app-layout, .app-main {
            background-color: var(--navy-main) !important;
            color: var(--text-light) !important;
        }

        .pc-sidebar {
            display: none !important;
        }

        /* Convert to top nav header */
        .mobile-header {
            display: flex !important;
            background: var(--navy-card) !important;
            padding: 15px 30px !important;
            border-bottom: 1px solid var(--border-dark) !important;
        }
        .mobile-header .brand-title { color: #FFF !important; font-size: 1.4rem !important; }
        .mobile-header .brand-sub { color: var(--gold-main) !important; }

        /* Hide the hamburger icon as we will use bottom nav */
        .mobile-header > div:nth-child(2) { display: none !important; }

        /* The main container */
        .app-main { padding: 30px 20px !important; }
        
        .card-floating {
            background: var(--navy-card) !important;
            border: 1px solid var(--border-dark) !important;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
            margin: 0 auto !important;
            max-width: 600px !important;
        }

        /* Top Check-in Tabs (VISITANTE, CRIANCA...) */
        #tab-checkin > .segmented-control {
            display: flex !important;
            background: transparent !important;
            border: none !important;
            border-bottom: 1px solid var(--border-dark) !important;
            max-width: 800px !important;
            margin: 0 auto 30px auto !important;
        }
        #tab-checkin > .segmented-control .segment-btn {
            color: var(--text-muted) !important;
            background: transparent !important;
            font-size: 0.95rem !important;
            padding: 12px 10px !important;
        }
        #tab-checkin > .segmented-control .segment-btn.active {
            color: var(--gold-main) !important;
            border-bottom: 2px solid var(--gold-main) !important;
            border-radius: 0 !important;
        }

        /* Input fields */
        input[type="text"], input[type="tel"], input[type="email"], select, textarea {
            background: var(--navy-main) !important;
            border: 1px solid var(--border-dark) !important;
            color: var(--text-light) !important;
        }
        input:focus, select:focus {
            border-color: var(--gold-main) !important;
        }

        /* Sub tabs (NOVO / JA VISITOU) */
        .visitor-subtabs {
            background: var(--navy-main) !important;
            border: 1px solid var(--border-dark) !important;
            gap: 0 !important;
            padding: 4px !important;
            border-radius: 6px !important;
            margin-bottom: 20px !important;
        }
        .visitor-subtabs .subtab-btn {
            color: var(--text-muted) !important;
            padding: 10px !important;
            font-size: 0.85rem !important;
            border-radius: 4px !important;
        }
        .visitor-subtabs .subtab-btn.active {
            background: var(--gold-main) !important;
            color: #000 !important;
        }
        .visitor-subtabs .subtab-btn.active::after { display: none !important; }

        /* Submit Button */
        .submit-btn-container, .btn-gold, #btn-submit-visitor {
            background: var(--gold-main) !important;
            color: #000 !important;
            font-weight: 700 !important;
            text-transform: uppercase !important;
        }
        .submit-btn-container .enter-badge { display: none !important; }

        /* Typography */
        h1, h2, h3, h4, label, p { color: var(--text-light) !important; }
        .page-title { color: #FFF !important; }
        .page-subtitle-top { display: none !important; }

        /* Hide Ultimas entradas / Fix grid */
        .pc-visitor-grid { display: block !important; }
        .pc-column-right { display: none !important; } /* Hide Ultimas entradas permanently from main view */
        
        /* Bottom Nav */
        .bottom-nav {
            display: flex !important;
            position: fixed !important;
            bottom: 0 !important;
            left: 0 !important;
            width: 100% !important;
            max-width: 100% !important;
            background: var(--navy-card) !important;
            border-top: 1px solid var(--border-dark) !important;
            z-index: 1000 !important;
            margin: 0 !important;
            transform: none !important;
            padding: 0 !important;
        }
        .bottom-nav .nav-item {
            padding: 15px 5px !important;
            border-top: 2px solid transparent !important;
            color: var(--text-muted) !important;
        }
        .bottom-nav .nav-item.active {
            border-top-color: var(--gold-main) !important;
            color: var(--text-light) !important;
        }

        /* Hide the bottom 4 cards duplicate */
        .four-cards-row { display: none !important; }
    </style>
'''
content = content.replace('</head>', dark_theme + '\n</head>')

# "Mais informacoes" replacement
content = content.replace('+ Informações Opcionais (Igreja, Convidado, etc.)', 'Mais informações')
content = content.replace('Mais informações (Igreja, Convidado, etc.)', 'Mais informações')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied.")
