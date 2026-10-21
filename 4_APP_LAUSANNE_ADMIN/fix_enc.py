with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('Concluda', 'Concluída')
content = content.replace('Histrico', 'Histórico')

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)
