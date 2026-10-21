import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

top_header_pattern = re.compile(r'<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">\s*<div style="display:flex; align-items:center; gap:15px;">\s*<div class="mobile-nav-toggle".*?</div>\s*</div>', re.DOTALL)

# Find it manually
start = content.find('<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">')
if start != -1:
    # find the next "<!-- PAGE: DASHBOARD -->" which is right after this header
    end = content.find('<!-- PAGE: DASHBOARD -->')
    if end != -1:
        new_top_header = """<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:30px; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 20px;">
                <div style="display:flex; align-items:center; gap:15px;">
                    <div class="mobile-nav-toggle" onclick="togglePastoralNav()">
                        <i class="fas fa-bars"></i>
                    </div>
                    <h2 style="margin:0; font-size:1.3rem; color:#f8fafc; font-weight:800; letter-spacing:2px;">CME LAUSANNE</h2>
                </div>
                <button onclick="AuthManager.logout()" style="background:transparent; color:var(--text-dim); border:none; cursor:pointer; font-weight:600; font-size: 0.9rem;">Sair <i class="fas fa-sign-out-alt"></i></button>
            </div>

            """
        content = content[:start] + new_top_header + content[end:]
        print("Top header replaced using substring search.")

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)
