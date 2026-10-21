import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the white card style with the new Navy Dark Theme style
old_style = 'div.style.cssText = "background:#fff; border:1px solid rgba(16, 185, 129, 0.3); padding:15px; border-radius:12px; display:flex; justify-content:space-between; align-items:center; box-shadow:0 4px 15px rgba(16, 185, 129, 0.05); margin-bottom:10px;";'

new_style = 'div.style.cssText = "background:#111827; border:1px solid #1F2937; padding:18px; border-radius:12px; display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; box-shadow:0 2px 8px rgba(0,0,0,0.1);";'

content = content.replace(old_style, new_style)

# Also update the innerHTML to match the new dark theme
# Make sure text colors use the right hex since CSS vars might not be available
old_html = """    div.innerHTML = 
        <div style="flex:1;">
            <strong style="font-size:1.15rem; display:block; color:var(--text-light); margin-bottom:4px;"></strong>
            <div style='font-size:0.85rem; color:var(--text-muted);'>Resp: <b></b></div>
        </div>
        <div style="text-align:right;">
            <div style="font-size:0.8rem; background:rgba(16, 185, 129, 0.1); color:#10B981; padding:4px 10px; border-radius:8px; font-weight:700; border:1px solid rgba(16,185,129,0.2);"><i class="fas fa-check-circle" style="margin-right:4px;"></i>Entregue</div>
            <div style="font-size:0.75rem; color:#64748b; margin-top:5px; font-weight:600;"></div>
        </div>
    ;"""

# Need to find the exact innerHTML from the file. I will use regex.
pattern = re.compile(r'div\.innerHTML = .*?;', re.DOTALL)
match = pattern.search(content)

if match:
    new_html = r'''    div.innerHTML = 
        <div style="flex:1;">
            <strong style="font-size:1.15rem; display:block; color:#F8FAFC; margin-bottom:4px;"></strong>
            <div style='font-size:0.85rem; color:#94A3B8;'>Resp: <b style="color:#CBD5E1;"></b></div>
        </div>
        <div style="text-align:right; display:flex; flex-direction:column; align-items:flex-end; gap:6px;">
            <div style="font-size:0.85rem; color:#94A3B8; font-weight:600;"></div>
            <div style="font-size:0.75rem; color:#10B981; font-weight:700; display:flex; align-items:center; gap:4px;"><span style="display:block; width:6px; height:6px; background:#10B981; border-radius:50%;"></span> Entregue</div>
        </div>
    ;'''
    content = content[:match.start()] + new_html + content[match.end():]
else:
    print("Could not find div.innerHTML pattern!")

with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated js/reception_kids_logic.js")
