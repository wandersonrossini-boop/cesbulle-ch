import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Nullify loadKPIs()
# Find `async function loadKPIs() {` and replace up to `async function loadEscalasDash() {`
pattern_kpi = re.compile(r"async function loadKPIs\(\) \{.*?\}\s+async function loadEscalasDash", re.DOTALL)
content = re.sub(pattern_kpi, "async function loadKPIs() {\n            // Desativado\n        }\n\n        async function loadEscalasDash", content)

# 2. Fix loadEscalas() upcoming dashboard logic
pattern_upcoming = re.compile(r"// Dashboard upcoming and recent filter.*?\n\s+}\);\n\s+\}\n\s+async function excluirEscala", re.DOTALL)
content = re.sub(pattern_upcoming, "\n            });\n        }\n\n        async function excluirEscala", content)

# 3. Fix loadEscalas() snap.empty dashboard logic
pattern_empty = re.compile(r"tbody\.innerHTML = '[^']+';\s*document\.getElementById\('dashboard-proximos-cultos'\)\.innerHTML = '[^']+';\s*document\.getElementById\('dashboard-recentes-cultos'\)\.innerHTML = '[^']+';")
content = re.sub(pattern_empty, "tbody.innerHTML = '<tr><td colspan=\"6\" style=\"text-align:center; color:var(--text-dim); padding:40px;\">Nenhuma escala criada.</td></tr>';", content)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied perfect fix.")
