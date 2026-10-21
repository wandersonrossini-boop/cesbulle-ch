with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('async function loadGabineteDashboard() {')
end = content.find('async function openNovaEscala() {')

if start != -1 and end != -1:
    print(content[start:end])
else:
    print("Not found")
