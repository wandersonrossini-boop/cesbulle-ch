import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the fake global-top-nav css
content = re.sub(r'\.global-top-nav\s*\{[^}]*\}', '', content)

# Update the segmented control to look like the floating menu
css_nav = '''
        /* NAVEGAÇÃO PRINCIPAL (VISITANTE | CRIANÇA | ONLINE | MURAL) */
        #tab-checkin > .segmented-control {
            display: flex !important;
            justify-content: center !important;
            background: transparent !important;
            border: none !important;
            padding: 0 20px !important;
            gap: 40px !important;
            margin-top: 5vh !important;
            margin-bottom: 4vh !important;
        }

        #tab-checkin > .segmented-control .segment-btn {
            background: transparent !important;
            border: none !important;
            color: var(--text-muted) !important;
            font-size: 0.95rem !important;
            font-weight: 600 !important;
            padding: 10px 10px !important;
            cursor: pointer !important;
            text-transform: uppercase !important;
            position: relative !important;
            transition: color 0.2s !important;
            border-radius: 0 !important;
            box-shadow: none !important;
        }

        #tab-checkin > .segmented-control .segment-btn.active {
            color: var(--gold-main) !important;
            background: transparent !important;
        }

        #tab-checkin > .segmented-control .segment-btn.active::after {
            content: '' !important;
            position: absolute !important;
            bottom: -5px !important;
            left: 0 !important;
            right: 0 !important;
            height: 2px !important;
            background: var(--gold-main) !important;
        }
'''

# Find where the old segmented control css is and replace it
content = re.sub(r'#tab-checkin > \.segmented-control\s*\{[^}]*\}', '', content)
content = content.replace('/* INJECTED DARK THEME */', '/* INJECTED DARK THEME */\n' + css_nav)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Restored top nav and styled it as requested.")
