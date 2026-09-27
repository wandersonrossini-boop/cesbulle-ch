import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the media query for app-main
target = '''@media(min-width: 900px) {
    .app-main {
        justify-content: center; /* Center vertically on large screens */
        padding-top: 2vh !important; /* Push it down a bit */
    }
}'''
replacement = '''@media(min-width: 900px) {
    .app-main {
        justify-content: flex-start;
        padding-top: 8vh !important; /* Moderate spacing from the top */
    }
}'''

content = content.replace(target, replacement)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Adjusted vertical positioning.")
