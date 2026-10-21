import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '<div id="tab-events" class="tab-section" style="display:none; height: 85vh; margin-top: -40px;">'
replace = '<div id="tab-events" class="tab-section" style="display:none; height: calc(100vh - 210px);">'

if target in content:
    content = content.replace(target, replace)
    print("Fixed Events tab inline styles.")
else:
    print("Target not found.")

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
