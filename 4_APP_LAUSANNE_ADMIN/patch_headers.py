import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update mobile header
mobile_target = '''        <div class="mobile-header">
        <div>
            <h2 class="brand-title">CME LAUSANNE</h2>
            <div class="brand-sub">RECEPÇÃO</div>
        </div>
        <div style="font-size: 1.2rem; cursor: pointer;" onclick="document.querySelector('.sidebar-nav').classList.toggle('show-mobile')"></div>
    </div>'''

mobile_replace = '''        <div class="mobile-header">
        <div>
            <h2 class="brand-title">CME LAUSANNE</h2>
            <div class="brand-sub">RECEPÇÃO</div>
        </div>
        <div style="font-size: 1.2rem; cursor: pointer; display: flex; gap: 15px; align-items: center;">
            <div onclick="window.parent.postMessage('go_home', '*');" style="font-size: 0.85rem; font-weight: 600; color: var(--gold); letter-spacing: 0.5px;">&larr; INÍCIO</div>
            <div onclick="document.querySelector('.sidebar-nav').classList.toggle('show-mobile')"></div>
        </div>
    </div>'''
content = content.replace(mobile_target, mobile_replace)


# 2. Update PC sidebar header
pc_target = '''        <aside class="pc-sidebar">
        <div class="sidebar-brand">
            <h2>CME<br>LAUSANNE</h2>
            <div class="sub-brand">RECEPÇÃO</div>
        </div>'''

pc_replace = '''        <aside class="pc-sidebar">
        <div class="sidebar-brand" style="position: relative;">
            <h2>CME<br>LAUSANNE</h2>
            <div class="sub-brand">RECEPÇÃO</div>
            <div onclick="window.parent.postMessage('go_home', '*');" style="cursor: pointer; font-size: 0.85rem; font-weight: 600; color: var(--gold); margin-top: 15px; letter-spacing: 0.5px;">&larr; INÍCIO</div>
        </div>'''
content = content.replace(pc_target, pc_replace)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Headers updated")
