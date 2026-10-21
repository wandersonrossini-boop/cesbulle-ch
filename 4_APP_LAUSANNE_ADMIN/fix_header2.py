with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = lines[:329]

clean_layout = '''                <!-- MOBILE ONLY HEADER -->
                <div class="mobile-header-only" style="display:none; justify-content:space-between; align-items:center; margin-bottom:20px;">
                    <div class="mobile-menu-btn" onclick="toggleSidebar()" style="display:flex; align-items:center; justify-content:center; background:var(--gold); color:#000; width:40px; height:40px; border-radius:8px; cursor:pointer;">
                        <i class="fas fa-bars"></i>
                    </div>
                    <img src="assets/logo_3.png" height="30" alt="CME">
                </div>

                <!-- PAGE: DASHBOARD -->
                <div id="page-dashboard" class="page-content active">
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;">
                        <h2 style="font-size: 1.4rem; font-weight: 800; color: #fff; margin:0;">Escalas</h2>
                        <button class="btn-gold" style="width:auto; padding:8px 16px; font-size:0.85rem;" onclick="openNovaEscala()"><i class="fas fa-plus"></i> CRIAR</button>
                    </div>

                    <div class="dashboard-grid" style="padding:0; grid-template-columns: 1fr 1fr;">
'''
new_lines.append(clean_layout)
new_lines.extend(lines[339:])

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Removed redundant CME LAUSANNE from main content.")
