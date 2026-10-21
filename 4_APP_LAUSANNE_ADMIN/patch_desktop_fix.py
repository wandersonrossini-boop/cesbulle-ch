import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''        /* Desktop Adjustments */
        @media (min-width: 900px) {
            #tab-checkin {
                margin: 2vh 15% 0 auto !important; /* Push it right on desktop */
            }'''

replacement = '''        /* Desktop Adjustments */
        @media (min-width: 900px) {
            #tab-checkin {
                max-width: 700px !important;
                width: 100% !important;
                padding: 0 !important;
                margin: 2vh 15% 0 auto !important; /* Push it right on desktop */
                overflow-x: visible !important;
            }'''

content = content.replace(target, replacement)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed desktop overrides for tab-checkin.")
