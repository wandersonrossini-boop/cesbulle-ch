with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<nav class="sidebar-nav">')
end = content.find('</nav>')
if start != -1 and end != -1:
    print(content[start:end])
