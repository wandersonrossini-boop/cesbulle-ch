import sys
import re

def clean_reception(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. Remove golden shadow effect style
    golden_shadow_regex = r'<style>\s*/\*\s*GOLDEN SHADOW EFFECT.*?<\/style>'
    html = re.sub(golden_shadow_regex, '', html, flags=re.DOTALL)

    # 2. Remove desktop bottom cards
    desktop_cards_regex = r'<div class="desktop-bottom-cards">.*?</div>\s*</div>\s*<!-- END pc-visitor-grid -->'
    # I need to be careful with regex here. It's better to find the start and carefully delete.
    if '<div class="desktop-bottom-cards">' in html:
        start_idx = html.find('<div class="desktop-bottom-cards">')
        end_idx = html.find('</div>', html.find('</div>', html.find('</div>', html.find('</div>', start_idx) + 1) + 1) + 1) + 6 # div has 4 cards
        # Just use string split or simple regex
        html = re.sub(r'<div class="desktop-bottom-cards">.*?</div>\s*</div>\s*</div>\s*</div>', '</div>\n</div>\n</div>', html, flags=re.DOTALL)
        
        # Actually it's simpler:
        html = re.sub(r'<div class="desktop-bottom-cards">.*?</p>\s*</div>\s*</div>', '', html, flags=re.DOTALL)

    # 3. Clean CSS variables and flat look
    css_replacements = {
        '--border-light: #e2e8f0;': '--border-light: #e5e7eb;',
        'border-radius: 12px;': 'border-radius: 4px;',
        'border-radius: 10px;': 'border-radius: 4px;',
        'border-radius: 8px;': 'border-radius: 4px;',
        'border-radius: 14px;': 'border-radius: 4px;',
        'box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);': 'box-shadow: none;',
        'box-shadow: 0 4px 12px rgba(0,0,0,0.1);': 'box-shadow: none;',
        'box-shadow: 0 10px 20px rgba(59, 130, 246, 0.3);': 'box-shadow: none;',
        'font-weight: 800;': 'font-weight: 600;',
        'font-weight: 700;': 'font-weight: 600;'
    }
    for old, new in css_replacements.items():
        html = html.replace(old, new)

    # 4. Fix mobile bottom-nav to not be position:fixed and overlapping
    # Let's change .bottom-nav from position: fixed; bottom: 20px; to position: relative; margin-top: 20px;
    html = html.replace('position: fixed;\n            bottom: 20px;', 'position: relative;\n            margin: 20px auto;')
    html = html.replace('padding-bottom: 150px;', 'padding-bottom: 20px;')
    html = html.replace('padding-bottom: 120px;', 'padding-bottom: 20px;')
    html = html.replace('border-radius: 35px;', 'border-radius: 4px;')

    # 5. Fix icons in form (make them minimal or remove them)
    # The Acolhedor bar
    html = html.replace('<i class="fas fa-user-tag"></i>', '')
    html = html.replace('<div class="pulse-dot"', '<div class="pulse-dot" style="display:none;"')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Refactored successfully")

clean_reception('recepcao_v2.html')
