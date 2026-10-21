import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('async function loadKPIs() {')
end = content.find('// LOADERS FOR PLACEHOLDERS')

if start != -1 and end != -1:
    new_func = "async function loadKPIs() {\n            // Desativado\n        }\n\n        "
    content = content[:start] + new_func + content[end:]
    
with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Disabled loadKPIs successfully.")
