import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

print("INICIO found:", content.find('INÍCIO') != -1)
print("mobile-header found:", content.find('mobile-header') != -1)
