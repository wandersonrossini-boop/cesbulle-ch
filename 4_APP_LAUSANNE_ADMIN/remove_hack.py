import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the -220px hack completely!
target = '''<div id="tab-services" class="tab-section" style="display:none; margin-top: -220px;">

        <div style="text-align:center; margin-bottom:20px; margin-top: 0;">'''

replace = '''<div id="tab-services" class="tab-section" style="display:none;">

        <div style="text-align:center; margin-bottom:20px;">'''

content = content.replace(target, replace)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Hack removed!")
