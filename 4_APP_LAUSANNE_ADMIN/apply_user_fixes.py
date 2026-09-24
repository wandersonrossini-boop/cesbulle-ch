import sys
import re

def apply_all_fixes(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. PREMIUM TYPOGRAPHY & REMOVE GOLD VARIABLES IN CSS
    html = re.sub(
        r'--font-body:.*?;',
        '--font-body: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", "Segoe UI", Roboto, sans-serif;',
        html
    )
    html = re.sub(
        r'--font-serif:.*?;',
        '--font-serif: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif;',
        html
    )
    html = html.replace('--gold: #a68a56;', '--gold: #0f172a;')
    html = html.replace('--gold-hover: #8b7348;', '--gold-hover: #1e293b;')
    html = html.replace('--gold-primary', '--gold')

    # Update .btn-gold styling in CSS to be premium slate black/blue
    html = html.replace('background: #a68a56 !important;', 'background: #0f172a !important;')
    html = html.replace('background: var(--gold);', 'background: #0f172a;')
    html = html.replace('color: #000;', 'color: #fff;')

    # 2. REMOVE ACOLHEDOR BAR HTML & CSS
    # CSS
    acolhedor_css_regex = r'/\*\s*RECEPTIONIST IDENTIFICATION BAR\s*\*/.*?\}\s*\}\s*\}'
    html = re.sub(acolhedor_css_regex, '', html, flags=re.DOTALL)
    html = html.replace('.acolhedor-bar i { color: var(--gold); font-size: 1.2rem; }', '')

    # HTML
    acolhedor_html_regex = r'<!-- ACOHLEDOR IDENTIFICATION -->.*?<!-- === TAB 0:'
    html = re.sub(acolhedor_html_regex, '<!-- === TAB 0:', html, flags=re.DOTALL)

    # 3. FIX "CRIANÇAS NÃO APARECEM NADA" (ADD MISSING #mode-child SECTION)
    child_mode_html = '''<!-- MODE CHILD (CRIANÇAS) -->
            <div id="mode-child" class="tab-content-area">
                <div class="card-floating">
                    <div class="segmented-control" style="margin-bottom:15px; background: #f8fafc; border-radius: 4px; border: 1px solid #e2e8f0; height: auto;">
                        <button class="segment-btn active" onclick="switchChildSubMode('exist', this)">LISTA DE CRIANÇAS</button>
                        <button class="segment-btn" onclick="switchChildSubMode('new', this)">NOVA CRIANÇA</button>
                    </div>

                    <div class="pc-visitor-grid">
                        <div class="pc-column-left">
                            <!-- SUB-MODE: EXISTING KIDS (LIST & SEARCH) -->
                            <div id="child-sub-exist" class="child-sub-area">
                                <div style="margin-bottom: 15px;">
                                    <h3 style="margin: 0 0 4px 0; font-size: 1.2rem; color: #0f172a; font-weight: 600;">Check-in de Crianças</h3>
                                    <p style="margin: 0; color: #64748b; font-size: 0.85rem;">Localize a criança para registrar a entrada na sala.</p>
                                </div>
                                <input type="text" id="child-search-input" placeholder="Digite o nome da criança ou responsável..." onkeyup="renderKidsSelection(this.value)" style="font-size:1rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:15px; background:#ffffff;">
                                <div id="child-search-results"></div>
                            </div>

                            <!-- SUB-MODE: NEW CHILD REGISTRATION -->
                            <div id="child-sub-new" class="child-sub-area" style="display:none;">
                                <div style="margin-bottom: 15px;">
                                    <h3 style="margin: 0 0 4px 0; font-size: 1.2rem; color: #0f172a; font-weight: 600;">Cadastrar Nova Criança</h3>
                                    <p style="margin: 0; color: #64748b; font-size: 0.85rem;">Preencha os dados do responsável e da criança.</p>
                                </div>

                                <div id="child-step-1">
                                    <label style="color:#0f172a; font-size:0.85rem; font-weight:600; display:block; margin-bottom:6px;">WhatsApp do Responsável *</label>
                                    <input type="tel" id="child-phone" placeholder="Digite o WhatsApp..." onkeyup="searchParentForChild(this.value)" style="font-size:1rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:10px; background:#ffffff;">
                                    <div id="parent-search-status" style="font-size:0.85rem; margin-bottom:15px; font-weight:500;"></div>
                                </div>

                                <div id="child-step-2" style="display:none;">
                                    <label style="color:#0f172a; font-size:0.85rem; font-weight:600; display:block; margin-bottom:6px;">Nome do Responsável *</label>
                                    <input type="text" id="child-parent" placeholder="Nome do responsável" onkeyup="checkChildStep(2)" style="font-size:1rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:15px; background:#ffffff;">

                                    <label style="color:#0f172a; font-size:0.85rem; font-weight:600; display:block; margin-bottom:6px;">Nome da Criança *</label>
                                    <input type="text" id="child-name" placeholder="Nome completo da criança" onkeyup="checkChildStep(2)" style="font-size:1rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:15px; background:#ffffff;">
                                </div>

                                <div id="child-step-3" style="display:none;">
                                    <label style="color:#0f172a; font-size:0.85rem; font-weight:600; display:block; margin-bottom:6px;">Faixa Etária *</label>
                                    <select id="child-age" onchange="checkChildStep(3)" style="font-size:0.95rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:15px; background:#ffffff;">
                                        <option value="">Selecione a faixa etária...</option>
                                        <option value="Berçário (0-2 anos)">Berçário (0-2 anos)</option>
                                        <option value="Maternal (3-5 anos)">Maternal (3-5 anos)</option>
                                        <option value="Kids (6-10 anos)">Kids (6-10 anos)</option>
                                        <option value="Juniores (11-12 anos)">Juniores (11-12 anos)</option>
                                    </select>

                                    <label style="color:#0f172a; font-size:0.85rem; font-weight:600; display:block; margin-bottom:6px;">Alergias / Restrições (opcional)</label>
                                    <input type="text" id="child-allergies" placeholder="Ex: Amendoim, Lactose..." style="font-size:1rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:15px; background:#ffffff;">

                                    <label style="color:#0f172a; font-size:0.85rem; font-weight:600; display:block; margin-bottom:6px;">Atenção Especial (opcional)</label>
                                    <input type="text" id="child-special" placeholder="Ex: TDAH, Cuidado especial..." style="font-size:1rem; padding:12px; border:1px solid #cbd5e1; border-radius:4px; width:100%; box-sizing:border-box; margin-bottom:15px; background:#ffffff;">
                                </div>

                                <div id="child-step-4" style="display:none; margin-bottom:15px;">
                                    <label style="display:flex; align-items:center; gap:8px; font-size:0.9rem; color:#0f172a;">
                                        <input type="checkbox" id="child-presentation-new" style="width:auto; margin:0;">
                                        Apresentação de Bebê no Culto
                                    </label>
                                </div>

                                <button id="btn-child-submit" onclick="submitChildNew()" class="btn-gold" style="display:none; width:100%; font-size:1rem; font-weight:600; padding:12px; margin-top:10px; border-radius:4px; background:#0f172a; color:#fff;">
                                    Registrar Entrada da Criança
                                </button>
                            </div>
                        </div>

                        <div class="pc-column-right">
                            <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:4px; padding:15px;">
                                <h4 style="margin:0 0 6px 0; color:#0f172a; font-size:0.95rem; font-weight:600;">Instruções Crianças</h4>
                                <p style="margin:0; font-size:0.85rem; color:#64748b; line-height:1.4;">
                                    Utilize a busca rápida para crianças já cadastradas. Em caso de primeiro acesso, preencha o formulário de cadastro com o WhatsApp do responsável.
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 1. VISITOR CONTENT -->'''

    if 'id="mode-child"' not in html:
        html = html.replace('<!-- 1. VISITOR CONTENT -->', child_mode_html)

    # Trigger loadAllKidsList in switchCheckinMode
    old_switch = 'if (target) {\n                    target.classList.add(\'active\');'
    new_switch = 'if (target) {\n                    target.classList.add(\'active\');\n                    if (mode === \'child\' && typeof window.loadAllKidsList === \'function\') window.loadAllKidsList();'
    html = html.replace(old_switch, new_switch)

    # 4. REMOVE ALL ICONS (<i class="..."></i>)
    icon_regex = r'<i\s+class="[^"]*"\s*>(?:</i>)?'
    html = re.sub(icon_regex, '', html)

    # Clean up empty i tags closing
    html = html.replace('</i>', '')

    # 5. REMOVE EMOJIS & STICKERS
    emojis = ['↵', '⚠️', '💎', '👷', '👑', '✨', '🔥', '⭐', '❤️', '🙏', '👍', '📌']
    for emoji in emojis:
        html = html.replace(emoji, '')

    # 6. REPLACE GOLD COLORS WITH SOBRE NEUTRAL/SLATE PALETTE
    gold_colors = ['#9e793e', '#d4af37', '#a68a56', '#c9a050', '#FFC72C', '#8b7348', '#86642d']
    for color in gold_colors:
        html = html.replace(color, '#0f172a')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)

    print("All fixes applied successfully.")

apply_all_fixes('recepcao_v2.html')
