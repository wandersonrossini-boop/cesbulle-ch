import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target5 = '''<div id="tab-services" class="tab-section" style="display:none; margin-top: -220px;">

        <div style="text-align:center; margin-bottom:20px; margin-top: 0;">'''
replace5 = '''<div id="tab-services" class="tab-section" style="display:none;">

        <div style="text-align:center; margin-bottom:20px;">'''
if target5 in content:
    content = content.replace(target5, replace5)
    print("Fixed target5")
else:
    print("Could not find target5")

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
