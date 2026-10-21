import os
os.system('git show HEAD~1:4_APP_LAUSANNE_ADMIN/gabinete.html > old_gabinete.html')
with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    for line in f:
        if 'id="page-' in line:
            print(line.strip())
