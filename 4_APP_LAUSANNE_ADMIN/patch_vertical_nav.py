import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Make the global-top-nav look like a floating menu with spacing
css_replacement = '''
        .global-top-nav {
            display: flex;
            justify-content: center;
            background: transparent;
            border: none; /* Removed full width border */
            padding: 0 20px;
            gap: 40px;
            margin-top: 5vh; /* ESPAÇO ENTRE CABEÇALHO E MENU */
            margin-bottom: 3vh; /* ESPAÇO ENTRE MENU E FORMULÁRIO */
        }

        .top-nav-btn {
            background: transparent;
            border: none;
            color: var(--text-muted);
            font-size: 0.95rem;
            font-weight: 600;
            padding: 10px 10px;
            cursor: pointer;
            text-transform: uppercase;
            position: relative;
            transition: color 0.2s;
        }

        .top-nav-btn.active {
            color: var(--gold-main);
        }

        .top-nav-btn.active::after {
            content: '';
            position: absolute;
            bottom: -5px;
            left: 0;
            right: 0;
            height: 2px;
            background: var(--gold-main);
        }
'''

# We need to replace the old .global-top-nav and .top-nav-btn rules in the injected CSS block
content = re.sub(r'\.global-top-nav\s*\{[^}]*\}', '', content)
content = re.sub(r'\.top-nav-btn\s*\{[^}]*\}', '', content)
content = re.sub(r'\.top-nav-btn\.active\s*\{[^}]*\}', '', content)
content = re.sub(r'\.top-nav-btn\.active::after\s*\{[^}]*\}', '', content)

# Inject the new css rules
content = content.replace('/* INJECTED DARK THEME */', '/* INJECTED DARK THEME */\n' + css_replacement)

# Also fix the .app-main padding so the whole block descends nicely
content = content.replace('padding-top: 5vh !important;', 'padding-top: 2vh !important;')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Nav vertical spacing patched.")
