import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('<!-- === TAB 3')
end = content.find('<!-- === TAB 4')
substring = content[start:end]

open_divs = substring.count('<div')
close_divs = substring.count('</div')

print(f"Open divs: {open_divs}, Close divs: {close_divs}")
