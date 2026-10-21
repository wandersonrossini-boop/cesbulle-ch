with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<div id="page-dashboard"')
end = content.find('<div id="page-lideres"')

if start != -1 and end != -1:
    print(content[start:end][3000:4500])
else:
    print("Not found")
