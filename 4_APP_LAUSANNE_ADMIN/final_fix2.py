with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip_kpi = False
skip_dash = False

for i, line in enumerate(lines):
    # Disable KPIs properly
    if "async function loadKPIs()" in line:
        new_lines.append("        async function loadKPIs() {\n            // Desativado\n        }\n")
        skip_kpi = True
        continue
    if skip_kpi and "async function loadAtaDigitalFeed()" in line:
        skip_kpi = False
        
    if skip_kpi:
        continue
        
    # Remove lines containing dashboard-proximos-cultos and dashboard-recentes-cultos
    if "dashboard-proximos-cultos" in line or "dashboard-recentes-cultos" in line:
        continue
        
    # Remove the whole logic block for Dashboard upcoming
    if "// Dashboard upcoming and recent filter" in line:
        skip_dash = True
        continue
        
    if skip_dash:
        # stop skipping when we reach the end of that block.
        # the block ends with "document.getElementById('dashboard-recentes-cultos')" which we removed.
        # actually, the block ends with "});" which is the end of `scalesListener = db.collection...`?
        # NO! It ends right before `});` of scalesListener.
        # Let's just look for "});" and if the NEXT line is "}" (end of loadEscalas)
        if "});" in line and i+1 < len(lines) and "}" in lines[i+1]:
            skip_dash = False
            new_lines.append(line)
        continue
        
    new_lines.append(line)
    
with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Applied fix cleanly.")
