import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Un-hide the segmented-control that was accidentally targeted by div:first-child
target_hide = '#tab-checkin > div:first-child { display: none !important; } /* Hide Bem-vindo text on PC */'
content = content.replace(target_hide, '/* Bem-vindo text was already removed */')

# 2. Hide 'Ver Últimas Entradas' details block completely
css_hide_ultimas = '''
        /* HIDE LATEST ENTRIES FROM RECEPTION MAIN VIEW AS REQUESTED */
        .ultimas-entradas-details {
            display: none !important;
        }
'''
content = content.replace('/* INJECTED DARK THEME */', '/* INJECTED DARK THEME */\n' + css_hide_ultimas)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Restored top nav and hid Últimas Entradas.")
