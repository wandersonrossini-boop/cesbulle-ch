import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the global centering and width restriction on .card-floating that broke Ao Vivo
target_card_floating = '''        .card-floating {
            background: var(--navy-card) !important;
            border: 1px solid var(--border-dark) !important;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
            margin: 0 auto !important;
            max-width: 700px !important;
        }'''

replacement_card_floating = '''        .card-floating {
            background: var(--navy-card) !important;
            border: 1px solid var(--border-dark) !important;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
            /* margin and max-width removed to prevent breaking global modules like Ao Vivo */
        }'''

content = content.replace(target_card_floating, replacement_card_floating)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed global margin and max-width from .card-floating.")
