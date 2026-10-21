with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('background:#111827; border:1px solid #1F2937;', 'background:transparent; border:1px solid rgba(255,255,255,0.03);')
content = content.replace('background:#111827; border:1px solid rgba(255,255,255,0.05);', 'background:transparent; border:1px solid rgba(255,255,255,0.03);')
content = content.replace('padding:20px;', 'padding:15px;')

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)
