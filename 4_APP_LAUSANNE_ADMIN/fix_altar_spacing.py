import re
with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace topbar padding and gap in the mobile query
old_topbar = """        @media (max-width: 900px) {
            .topbar {
                flex-direction: column;
                align-items: flex-start;
                gap: 20px;
                padding: 25px 20px;
            }"""
new_topbar = """        @media (max-width: 900px) {
            .topbar {
                flex-direction: column;
                align-items: flex-start;
                gap: 15px;
                padding: 15px 20px;
            }"""
content = content.replace(old_topbar, new_topbar)

# Also let's adjust `.mobile-brand-bar` margin-bottom which I set to 15px, maybe 10px is better.
content = content.replace('.mobile-brand-bar { margin-bottom: 15px !important; }', '.mobile-brand-bar { margin-bottom: 10px !important; }')

# And `.header-left` margin-bottom is currently 25px, let's reduce to 15px.
content = content.replace('.header-left { flex-direction: column; align-items: flex-start; gap: 8px; margin-bottom: 25px; }', '.header-left { flex-direction: column; align-items: flex-start; gap: 4px; margin-bottom: 15px; }')

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Adjusted topbar spacing")
