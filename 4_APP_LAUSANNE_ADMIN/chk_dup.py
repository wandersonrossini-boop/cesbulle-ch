with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

print(content.count('<!DOCTYPE html>'))
print(content.count('function loadKPIs()'))
