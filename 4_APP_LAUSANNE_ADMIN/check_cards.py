import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure I didn't mess up the closing braces for loadGabineteCards
start = content.find('async function loadGabineteCards() {')
end = content.find('async function salvarDiretrizPastoral(btn) {')
print(content[start:end])
