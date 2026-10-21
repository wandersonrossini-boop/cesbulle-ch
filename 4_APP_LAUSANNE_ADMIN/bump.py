with open('index.html', 'r', encoding='utf-8') as idx:
    idx_content = idx.read()
idx_content = idx_content.replace('70.3.104', '70.3.105')
with open('index.html', 'w', encoding='utf-8') as idx:
    idx.write(idx_content)
