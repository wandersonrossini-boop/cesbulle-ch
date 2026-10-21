with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False

for i, line in enumerate(lines):
    # Disable KPIs properly
    if "async function loadKPIs()" in line:
        new_lines.append("        async function loadKPIs() {\n            // Desativado\n        }\n")
        skip = True
        continue
    if skip and "function loadEscalas()" in line:
        skip = False
    if skip and "async function loadAtaDigitalFeed()" in line:
        skip = False
        
    if skip:
        continue
        
    # Remove lines containing dashboard-proximos-cultos and dashboard-recentes-cultos
    if "dashboard-proximos-cultos" in line or "dashboard-recentes-cultos" in line:
        continue
        
    # Remove the whole logic block for Dashboard upcoming
    if "// Dashboard upcoming and recent filter" in line:
        skip = True
        continue
    if skip and "});" in line and "document.getElementById('dashboard-recentes-cultos')" in lines[i+1]:
        # wait, we already handle removing dashboard-recentes-cultos
        pass
        
    new_lines.append(line)
    
with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Applied fix cleanly.")
