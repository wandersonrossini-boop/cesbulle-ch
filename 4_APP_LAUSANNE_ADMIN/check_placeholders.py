with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    old_content = f.read()

count = old_content.count('<!-- OTHER PAGES PLACEHOLDERS -->')
print(f"Count: {count}")
for i, line in enumerate(old_content.splitlines()):
    if '<!-- OTHER PAGES PLACEHOLDERS -->' in line:
        print(f"Line: {i+1}")
