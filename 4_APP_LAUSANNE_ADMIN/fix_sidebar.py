import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Rename Dashboard to Início
content = content.replace('<span>Dashboard</span>', '<span>Início</span>', 1)

# 2. Remove Escala de Cultos from Sidebar
old_escala_nav = """                <div class="nav-item" onclick="switchPage('escalas')" id="nav-escalas">
                    <i class="fas fa-calendar-alt"></i>
                    <span>Escala de Cultos</span>
                </div>"""
content = content.replace(old_escala_nav, "")

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated sidebar nav")
