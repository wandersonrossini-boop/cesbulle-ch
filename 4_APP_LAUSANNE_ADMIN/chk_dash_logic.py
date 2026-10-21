with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()
start = content.find('// Dashboard upcoming and recent filter')
end = content.find('function togglePastoralNav()')
print(content[start:end])
