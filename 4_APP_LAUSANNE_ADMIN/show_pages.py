import re
with open('gabinete.html', 'r', encoding='utf-8') as f:
    for line in f:
        if 'id="page-' in line:
            print(line.strip())
