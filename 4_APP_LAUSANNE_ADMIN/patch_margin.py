import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''<div style="text-align:center; margin-bottom:20px; margin-top:-120px;">'''
replacement = '''<div style="text-align:center; margin-bottom:20px; margin-top:-220px;">'''

if target in content:
    content = content.replace(target, replacement)
    with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Updated margin-top successfully.")
else:
    print("Target string not found!")

