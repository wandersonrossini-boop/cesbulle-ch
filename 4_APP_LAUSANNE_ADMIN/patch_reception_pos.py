import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''        #tab-checkin {
            max-width: 700px;
            margin: 6vh auto 0 auto !important;
            width: 100%;
        }'''

replacement = '''        #tab-checkin {
            max-width: 700px;
            /* margin-top: 2vh to move it up */
            /* margin-left: auto, margin-right: 15% pushes it rightwards within the container */
            margin: 2vh 15% 0 auto !important; 
            width: 100%;
        }'''

content = content.replace(target, replacement)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Moved tab-checkin up and to the right.")
