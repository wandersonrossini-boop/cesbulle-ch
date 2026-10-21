with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()
start = content.find('async function loadGabineteCards() {')
end = content.find('async function salvarDiretrizPastoral(btn) {')
print(content[start:end])
