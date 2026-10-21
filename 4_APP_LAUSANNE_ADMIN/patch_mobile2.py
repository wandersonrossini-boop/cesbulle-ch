import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target_mobile = '''        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 700px;
            margin: 0 auto !important; /* Mobile default: centered with no huge margins */
            width: 100%;
        }'''

replacement_mobile = '''        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 700px;
            margin: 0 auto !important; /* Mobile default: centered with no huge margins */
            padding: 0 15px !important; /* Breathing room for mobile */
            width: 100%;
            box-sizing: border-box;
        }'''

content = content.replace(target_mobile, replacement_mobile)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Added side padding for mobile.")
