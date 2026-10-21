with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('// Dashboard upcoming and recent filter')
end = content.find("document.getElementById('dashboard-escalas-recentes').innerHTML")
end = content.find(';', end) + 1

if start != -1 and end != -1:
    content = content[:start] + content[end:]
    
with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed loadEscalas using string slice")
