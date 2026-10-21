import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r"document\.getElementById\('dashboard-proximos-cultos'\)\.innerHTML[^;]+;", "", content)
content = re.sub(r"document\.getElementById\('dashboard-recentes-cultos'\)\.innerHTML[^;]+;", "", content)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Cleaned up remaining dashboard lines in snap.empty")
