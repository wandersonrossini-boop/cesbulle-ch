import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Revert the app-main media query
target_app_main = '''@media(min-width: 900px) {
    .app-main {
        justify-content: flex-start;
        padding-top: 4vh !important; /* Moderate spacing from the top */
    }
}'''
replacement_app_main = '''@media(min-width: 900px) {
    .app-main {
        justify-content: flex-start; /* Keep flex-start globally so it doesn't push down other tabs */
        padding-top: 0 !important; /* Remove the aggressive top padding globally */
    }
}'''
content = content.replace(target_app_main, replacement_app_main)

# 2. Remove the global .tab-section and segmented-control center rules
css_center_pattern = r'/\* Center all tab sections.*?\*/\s*\.tab-section\s*\{[^}]*\}\s*/\*.*?\*/\s*\.tab-section > \.segmented-control\s*\{[^}]*\}'
content = re.sub(css_center_pattern, '', content, flags=re.DOTALL)

# 3. Apply the specific fixes to #tab-checkin (Reception) ONLY!
css_reception_only = '''
        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 700px;
            margin: 4vh auto 0 auto; /* Margin-top for moderate vertical spacing, auto for horizontal center */
            width: 100%;
        }

        #tab-checkin > .segmented-control {
            display: flex !important;
            justify-content: center !important;
            margin: 0 auto 20px auto !important;
            max-width: 700px !important;
        }
'''

content = content.replace('/* INJECTED DARK THEME */', '/* INJECTED DARK THEME */\n' + css_reception_only)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Reverted global changes and isolated to Reception.")
