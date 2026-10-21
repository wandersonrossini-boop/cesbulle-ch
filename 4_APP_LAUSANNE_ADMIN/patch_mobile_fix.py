import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update #tab-checkin mobile rules to reclaim space and prevent overflow
target_tab_checkin = '''        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 700px;
            margin: 0 auto !important; /* Mobile default: centered with no huge margins */
            padding: 0 15px !important; /* Breathing room for mobile */
            width: 100%;
            box-sizing: border-box;
        }'''

replacement_tab_checkin = '''        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 100vw;
            margin: 0 -10px !important; /* Reclaim some left/right space from parent padding */
            padding: 0 10px !important; 
            width: calc(100% + 20px) !important;
            box-sizing: border-box;
            overflow-x: hidden; /* Prevent horizontal overflow */
        }'''
content = content.replace(target_tab_checkin, replacement_tab_checkin)

# 2. Update .segmented-control for mobile to have more lateral margin
target_nav = '''        #tab-checkin > .segmented-control {
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

replacement_nav = '''        #tab-checkin > .segmented-control {
            display: flex !important;
            justify-content: flex-start !important; /* Safe alignment for horizontal scrolling */
            background: transparent !important;
            border: none !important;
            padding: 0 15px !important; /* Increase lateral margin so MURAL is not so close to the edge */
            gap: 15px !important;
            margin-bottom: 2vh !important;
            max-width: 100% !important;
            overflow-x: auto; 
            -webkit-overflow-scrolling: touch;
            box-sizing: border-box;
        }'''
content = content.replace(target_nav, replacement_nav)

# 3. Ensure card-floating has box-sizing border-box everywhere so it doesn't overflow
target_card_floating = '''        .card-floating {
            background: var(--navy-card) !important;
            border: 1px solid var(--border-dark) !important;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
            /* margin and max-width removed to prevent breaking global modules like Ao Vivo */
        }'''
replacement_card_floating = '''        .card-floating {
            background: var(--navy-card) !important;
            border: 1px solid var(--border-dark) !important;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
            box-sizing: border-box !important;
            max-width: 100% !important;
            /* margin and max-width removed to prevent breaking global modules like Ao Vivo */
        }'''
content = content.replace(target_card_floating, replacement_card_floating)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Applied strict width constraints and reclaimed padding space.")
