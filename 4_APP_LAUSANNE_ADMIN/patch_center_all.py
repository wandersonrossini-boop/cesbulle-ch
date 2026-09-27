import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Subir o conteúdo: Reduce padding-top in app-main from 8vh to 4vh
content = content.replace('padding-top: 8vh !important;', 'padding-top: 4vh !important;')

# 2. Corrigir o centro: Apply center alignment and max-width to ALL .tab-section
# so that any module (Ao Vivo, Agendar, etc) is centralized.
css_center = '''
        /* Center all tab sections (Ao Vivo, Agendar, Servir, etc) */
        .tab-section {
            max-width: 700px;
            margin: 0 auto;
            width: 100%;
        }

        /* Ensure all segmented controls inside any tab are centered */
        .tab-section > .segmented-control {
            display: flex !important;
            justify-content: center !important;
            margin: 0 auto 20px auto !important;
            max-width: 700px !important;
        }
'''

content = content.replace('/* INJECTED DARK THEME */', '/* INJECTED DARK THEME */\n' + css_center)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Ao Vivo (and other modules) centering and vertical position adjusted.")
