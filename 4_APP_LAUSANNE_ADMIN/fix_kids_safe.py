import re

with open('kids.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the root CSS variables with navy theme
old_vars = """        :root {
            --bg-light: #F0F4F8; /* Light blue/grey background */
            --card-bg: #FFFFFF;
            --text-dark: #1E293B; /* Navy text */
            --text-muted: #64748B;
            --accent-blue: #0284C7; /* Blue accent instead of gold */
            --border-line: #E2E8F0;
            --gold: #C9A050;
            --red: #EF4444;
        }"""
        
new_vars = """        :root {
            /* Navy Blue Dark Theme */
            --bg-dark: #090e17; /* Very dark navy */
            --card-bg: #111827; /* Slightly lighter */
            --border-line: #1f2937; /* Subtle border */
            
            --text-light: #F8FAFC;
            --text-muted: #94A3B8;
            
            --gold: #C9A050;
            --green: #10B981;
            --red: #EF4444;
        }"""
content = content.replace(old_vars, new_vars)

# Replace html, body styles
old_body = """        html, body {
            background: var(--bg-light);
            color: var(--text-dark);"""
new_body = """        html, body {
            background: var(--bg-dark);
            color: var(--text-light);"""
content = content.replace(old_body, new_body)

# Replace header styles
old_header = """        .header h1 { font-size: 2.2rem; font-weight: 800; color: var(--text-dark); line-height: 1.1; margin-bottom: 5px; }"""
new_header = """        .header h1 { font-size: 2.2rem; font-weight: 800; color: var(--text-light); line-height: 1.1; margin-bottom: 5px; }"""
content = content.replace(old_header, new_header)

# Replace tab-btn active styles
old_tab_active = """.tab-btn.active { color: var(--accent-blue); }
        .tab-btn.active::after { content: ''; position: absolute; bottom: -1px; left: 0; width: 100%; height: 2px; background: var(--accent-blue); }"""
new_tab_active = """.tab-btn.active { color: var(--gold); }
        .tab-btn.active::after { content: ''; position: absolute; bottom: -1px; left: 0; width: 100%; height: 2px; background: var(--gold); }"""
content = content.replace(old_tab_active, new_tab_active)

# Replace kid-card text colors
old_kid_name = """.kid-name { font-size: 1.15rem; font-weight: 700; color: var(--text-dark); margin-bottom: 4px; }"""
new_kid_name = """.kid-name { font-size: 1.15rem; font-weight: 700; color: var(--text-light); margin-bottom: 4px; }"""
content = content.replace(old_kid_name, new_kid_name)

# Replace confirm button color
old_btn_confirm = """.btn-confirm { background: transparent; color: var(--accent-blue);"""
new_btn_confirm = """.btn-confirm { background: transparent; color: var(--gold);"""
content = content.replace(old_btn_confirm, new_btn_confirm)

old_btn_confirm_hover = """.btn-confirm:hover { color: #0369A1; }"""
new_btn_confirm_hover = """.btn-confirm:hover { color: #fff; }"""
content = content.replace(old_btn_confirm_hover, new_btn_confirm_hover)

# Replace presence header text color
old_presence_title = """.presence-title { font-size: 0.95rem; font-weight: 700; color: var(--text-dark); text-transform: uppercase; letter-spacing: 1px; }"""
new_presence_title = """.presence-title { font-size: 0.95rem; font-weight: 700; color: var(--text-light); text-transform: uppercase; letter-spacing: 1px; }"""
content = content.replace(old_presence_title, new_presence_title)

# Let's bump the version in index.html to cache bust
with open('index.html', 'r', encoding='utf-8') as idx:
    idx_content = idx.read()
idx_content = idx_content.replace('70.3.89', '70.3.90')
with open('index.html', 'w', encoding='utf-8') as idx:
    idx.write(idx_content)

with open('kids.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied dark theme to clean kids.html safely")
