import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('function renderEscalaContent')
if start == -1:
    print("Function not found! Let me print the whole JS part.")
    start = content.find('<script>')
    if start != -1:
        sub = content[start:start+1000]
        print(sub.encode('ascii', 'ignore').decode('ascii'))
else:
    sub = content[start-200:start+2500]
    print(sub.encode('ascii', 'ignore').decode('ascii'))
