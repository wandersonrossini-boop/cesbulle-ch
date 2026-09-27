import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the generic display flex with conditional logic for reception
target = '''            document.getElementById('view-login').style.display='none';
            document.getElementById('app-header').style.display='flex';
            document.getElementById('app-container').style.display='block';'''

replacement = '''            document.getElementById('view-login').style.display='none';
            document.getElementById('app-container').style.display='block';
            
            if (moduleName === 'reception') {
                document.getElementById('app-header').style.display='none';
                document.getElementById('app-container').style.top='0px';
                document.getElementById('app-container').style.height='100%';
            } else {
                document.getElementById('app-header').style.display='flex';
                document.getElementById('app-container').style.top='60px';
                document.getElementById('app-container').style.height='calc(100% - 60px)';
            }'''

content = content.replace(target, replacement)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Index.html patched for reception header removal.")
