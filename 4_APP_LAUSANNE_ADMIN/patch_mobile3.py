import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target_nav = '''        #tab-checkin > .segmented-control {
            display: flex !important;
            justify-content: space-between !important; /* Better distribution on mobile */
            background: transparent !important;
            border: none !important;
            padding: 0 10px !important; /* Less padding on mobile */
            gap: 10px !important; /* Smaller gap on mobile */
            margin-bottom: 2vh !important;
            max-width: 100% !important;
            overflow-x: auto; /* Prevent cut-off */
        }'''

replacement_nav = '''        #tab-checkin > .segmented-control {
            display: flex !important;
            justify-content: flex-start !important; /* Safe alignment for horizontal scrolling */
            background: transparent !important;
            border: none !important;
            padding: 0 5px !important;
            gap: 15px !important; /* Moderate gap */
            margin-bottom: 2vh !important;
            max-width: 100% !important;
            overflow-x: auto; /* Allow scrolling if it doesn't fit */
            -webkit-overflow-scrolling: touch; /* Smooth scrolling on iOS */
        }'''

content = content.replace(target_nav, replacement_nav)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Improved mobile segmented control alignment.")
