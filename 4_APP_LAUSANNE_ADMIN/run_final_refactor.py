import re

def execute_refactor(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. Update font imports & root variables in style
    html = re.sub(r'<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/.*?">', '', html)

    style_override = '''
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap">
    <style>
        :root {
            --navy-main: #0B1626;
            --navy-hover: #14263D;
            --gold-accent: #C9A96A;
            --bg-page: #F8FAFC;
            --bg-card: #FFFFFF;
            --text-main: #0F172A;
            --text-muted: #64748B;
            --border-color: #E5E7EB;
            --font-inter: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            --gold: #C9A96A;
            --gold-hover: #14263D;
        }

        body {
            background-color: var(--bg-page) !important;
            background: var(--bg-page) !important;
            color: var(--text-main) !important;
            font-family: var(--font-inter) !important;
            margin: 0;
            padding-bottom: 40px;
        }

        h1, h2, h3, h4, label, input, select, button, span, p, div {
            font-family: var(--font-inter) !important;
        }

        .pc-sidebar {
            background: var(--navy-main) !important;
            border-right: 1px solid rgba(255, 255, 255, 0.08) !important;
        }
        .sidebar-header h2 {
            color: #FFFFFF !important;
            font-size: 1.25rem !important;
            font-weight: 700 !important;
        }
        .sidebar-header h2 span {
            color: var(--gold-accent) !important;
        }
        .sidebar-menu .segment-btn {
            color: rgba(255, 255, 255, 0.7) !important;
            font-weight: 500 !important;
            font-size: 0.95rem !important;
            padding: 12px 16px !important;
            border-radius: 4px !important;
            border: none !important;
            background: transparent !important;
            text-align: left !important;
            width: 100% !important;
        }
        .sidebar-menu .segment-btn.active {
            background: var(--navy-hover) !important;
            color: #FFFFFF !important;
            border-left: 3px solid var(--gold-accent) !important;
            border-radius: 0 4px 4px 0 !important;
        }

        .btn-gold, button.btn-primary {
            background: var(--navy-main) !important;
            color: #FFFFFF !important;
            font-weight: 600 !important;
            font-size: 1rem !important;
            border-radius: 4px !important;
            border: none !important;
            padding: 14px 20px !important;
            cursor: pointer !important;
            transition: background 0.2s ease !important;
            text-transform: none !important;
            letter-spacing: normal !important;
        }
        .btn-gold:hover, button.btn-primary:hover {
            background: var(--navy-hover) !important;
        }

        .page-title {
            font-size: 30px !important;
            font-weight: 700 !important;
            color: var(--text-main) !important;
            margin: 0 0 4px 0 !important;
            letter-spacing: -0.5px !important;
        }
        @media (max-width: 768px) {
            .page-title {
                font-size: 26px !important;
            }
        }
        .page-subtitle-top {
            font-size: 13px !important;
            color: var(--text-muted) !important;
            font-weight: 600 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.5px !important;
            margin: 0 0 2px 0 !important;
        }

        .card-floating {
            background: var(--bg-card) !important;
            border: 1px solid var(--border-color) !important;
            border-radius: 4px !important;
            box-shadow: none !important;
            padding: 24px !important;
        }

        .segmented-control {
            display: flex !important;
            background: #F1F5F9 !important;
            border-radius: 4px !important;
            padding: 3px !important;
            border: 1px solid var(--border-color) !important;
            gap: 4px !important;
            margin-bottom: 20px !important;
        }
        .segment-btn {
            flex: 1 !important;
            padding: 10px 14px !important;
            font-size: 0.85rem !important;
            font-weight: 600 !important;
            color: var(--text-muted) !important;
            border: none !important;
            background: transparent !important;
            border-radius: 4px !important;
            cursor: pointer !important;
            text-align: center !important;
        }
        .segment-btn.active {
            background: var(--navy-main) !important;
            color: #FFFFFF !important;
        }

        .four-access-grid {
            display: grid !important;
            grid-template-columns: repeat(4, 1fr) !important;
            gap: 12px !important;
            margin-top: 25px !important;
        }
        @media (max-width: 600px) {
            .four-access-grid {
                grid-template-columns: repeat(2, 1fr) !important;
            }
        }
        .access-btn {
            background: #FFFFFF !important;
            border: 1px solid var(--border-color) !important;
            border-radius: 4px !important;
            padding: 14px 10px !important;
            text-align: center !important;
            color: var(--text-main) !important;
            font-weight: 600 !important;
            font-size: 0.9rem !important;
            cursor: pointer !important;
            transition: all 0.2s ease !important;
        }
        .access-btn:hover {
            border-color: var(--navy-main) !important;
            background: #F1F5F9 !important;
        }

        /* Hide bottom nav bar on mobile if redundant */
        .bottom-nav {
            display: none !important;
        }

        label {
            font-size: 14px !important;
            font-weight: 600 !important;
            color: var(--text-main) !important;
            margin-bottom: 6px !important;
            display: block !important;
        }

        input[type="text"], input[type="tel"], select {
            font-size: 16px !important;
            font-weight: 400 !important;
            padding: 12px 14px !important;
            border: 1px solid var(--border-color) !important;
            border-radius: 4px !important;
            background: #FFFFFF !important;
            color: var(--text-main) !important;
            margin-bottom: 16px !important;
        }

        input:focus, select:focus {
            border-color: var(--navy-main) !important;
            outline: none !important;
        }

        /* Hide any explanatory text below Visitante */
        .remove-subtitle {
            display: none !important;
        }
    </style>
'''

    if '</head>' in html:
        html = html.replace('</head>', style_override + '\n</head>')

    # Replace title header inside #tab-checkin
    header_old_regex = r'<div style="text-align:center; margin-bottom:30px;">.*?</div>'
    header_new = '''<div style="margin-bottom: 20px;">
                <p class="page-subtitle-top">Recepção</p>
                <h1 class="page-title">Visitante</h1>
            </div>'''
    html = re.sub(header_old_regex, header_new, html, flags=re.DOTALL)

    # Remove any descriptions inside visitor registration header
    html = re.sub(r'<h2[^>]*>Registrar visitante</h2>\s*<p[^>]*>.*?</p>', '<h2 style="font-size: 1.25rem; font-weight: 700; color: #0f172a; margin: 0 0 16px 0;">Registrar Entrada</h2>', html, flags=re.DOTALL)

    # Clean the bottom cards or access buttons to strictly be ONLY TITLES: Criança | Eventos | Online / QR | Mural
    four_access_html = '''
    <!-- SOMENTE OS 4 ACESSOS (SOMENTE TITULOS) -->
    <div class="four-access-grid">
        <div class="access-btn" onclick="switchCheckinMode('child', this)">Criança</div>
        <div class="access-btn" onclick="setTab('events')">Eventos</div>
        <div class="access-btn" onclick="switchCheckinMode('online', this)">Online / QR</div>
        <div class="access-btn" onclick="switchCheckinMode('mural', this)">Mural</div>
    </div>
    '''

    # Remove old quick-card desktop bottom cards block if present
    html = re.sub(r'<div class="desktop-bottom-cards">.*?</div>\s*</div>', four_access_html, html, flags=re.DOTALL)

    # Strip out any remaining FontAwesome icons and emojis
    html = re.sub(r'<i\b[^>]*>(?:</i>)?', '', html)
    html = html.replace('</i>', '')

    emojis = ['↵', '⚠️', '💎', '👷', '👑', '✨', '🔥', '⭐', '❤️', '🙏', '👍', '📌']
    for emoji in emojis:
        html = html.replace(emoji, '')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)

    print("Refactor applied cleanly.")

execute_refactor('recepcao_v2.html')
