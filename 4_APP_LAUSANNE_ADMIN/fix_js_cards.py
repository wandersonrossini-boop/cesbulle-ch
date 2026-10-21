import re

with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to find where I broke the innerHTML and fix it.
pattern = re.compile(r'div\.innerHTML = \s*<div style="flex:1;">', re.DOTALL)
match = pattern.search(content)

if match:
    old = content[match.start():match.end()]
    new_text = r'''div.innerHTML = `
        <div style="flex:1;">'''
    content = content.replace(old, new_text)

# And fix the closing backtick which might be missing.
# Wait, let's just do a clean replacement of that whole block!
