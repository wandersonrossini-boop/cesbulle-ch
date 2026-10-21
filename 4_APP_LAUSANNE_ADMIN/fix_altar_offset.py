import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to make altar also take full screen like reception!
old_js = """            if (moduleName === 'reception') {
                document.getElementById('app-header').style.display='none';
                document.getElementById('app-container').style.top='0px';
                document.getElementById('app-container').style.height='100%';
            } else {
                document.getElementById('app-header').style.display='flex';
                document.getElementById('app-container').style.top='60px';
                document.getElementById('app-container').style.height='calc(100% - 60px)';
            }"""

new_js = """            if (moduleName === 'reception' || moduleName === 'altar') {
                document.getElementById('app-header').style.display='none';
                document.getElementById('app-container').style.top='0px';
                document.getElementById('app-container').style.height='100%';
            } else {
                document.getElementById('app-header').style.display='flex';
                document.getElementById('app-container').style.top='60px';
                document.getElementById('app-container').style.height='calc(100% - 60px)';
            }"""

content = content.replace(old_js, new_js)

# Remove the redundant `if(moduleName === 'altar') ...` below
content = content.replace("if(moduleName === 'altar') document.getElementById('app-header').style.display='none';", "")

# Bump version to 70.3.92
content = content.replace('70.3.91', '70.3.92')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed top offset for Altar in index.html")
