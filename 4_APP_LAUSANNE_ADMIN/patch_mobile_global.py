import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Clean up the hacky tab-checkin mobile rules from previous fix
target_tab_checkin = '''        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 100vw;
            margin: 0 -10px !important; /* Reclaim some left/right space from parent padding */
            padding: 0 10px !important; 
            width: calc(100% + 20px) !important;
            box-sizing: border-box;
            overflow-x: hidden; /* Prevent horizontal overflow */
        }'''
replacement_tab_checkin = '''        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 100%;
            margin: 0 auto !important; 
            padding: 0 !important; 
            width: 100% !important;
            box-sizing: border-box !important;
        }'''
content = content.replace(target_tab_checkin, replacement_tab_checkin)

# 2. Fix global app-main padding on mobile (it was 20px from app-main + 20px from container = 40px wasted space)
target_app_main_mobile = '''        @media (max-width: 899px) {
            .app-main {
                padding: 24px 20px;
            }
        }'''
replacement_app_main_mobile = '''        @media (max-width: 899px) {
            .app-main {
                padding: 15px 15px !important; /* Reclaim massive 40px double padding */
                overflow-x: hidden !important;
                width: 100% !important;
                box-sizing: border-box !important;
            }
            .container {
                padding: 0 !important; /* Remove double padding */
                width: 100% !important;
                box-sizing: border-box !important;
            }
            body {
                overflow-x: hidden !important;
            }
        }'''
content = content.replace(target_app_main_mobile, replacement_app_main_mobile)

# 3. Ensure subtabs and inputs are box-sizing border box
target_inputs = '''        /* Input fields */
        input[type="text"], input[type="tel"], input[type="email"], select, textarea {
            background: var(--navy-main) !important;
            border: 1px solid var(--border-dark) !important;
            color: var(--text-light) !important;
        }'''
replacement_inputs = '''        /* Input fields */
        input[type="text"], input[type="tel"], input[type="email"], select, textarea {
            background: var(--navy-main) !important;
            border: 1px solid var(--border-dark) !important;
            color: var(--text-light) !important;
            box-sizing: border-box !important;
            width: 100%;
            max-width: 100% !important;
        }'''
content = content.replace(target_inputs, replacement_inputs)


with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Applied strict mobile padding fixes globally.")
