import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Just remove the entire // Dashboard upcoming block inside loadEscalas
pattern = re.compile(r"// Dashboard upcoming and recent filter.*?document\.getElementById\('dashboard-escalas-recentes'\)\.innerHTML.*?\} \catch\(e\)", re.DOTALL)
content = re.sub(r"// Dashboard upcoming and recent filter.*?document\.getElementById\('dashboard-escalas-recentes'\)\.innerHTML[^;]*;", "", content, flags=re.DOTALL)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed loadEscalas")
