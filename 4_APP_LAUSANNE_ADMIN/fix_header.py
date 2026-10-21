with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = lines[:329]

# We want to skip from 329 to 365, replacing it with the clean layout
clean_layout = '''                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:30px; padding-bottom: 20px;">
                    <h2 style="margin:0; font-size:1.3rem; color:#f8fafc; font-weight:800; letter-spacing:2px;">CME LAUSANNE</h2>
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
new_lines.extend(lines[365:])

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("Cleaned up top area.")
