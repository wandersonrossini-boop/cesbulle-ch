import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Revert the .app-main change that I made in my script
# I need to put it back exactly as it was in the commit
target_app_main = '''@media(min-width: 900px) {
    .app-main {
        justify-content: flex-start; /* Do not push down all modules */
        padding-top: 0 !important;
    }
}'''
replacement_app_main = '''@media(min-width: 900px) {
    .app-main {
        justify-content: center; /* Center vertically on large screens */
        padding-top: 2vh !important; /* Push it down a bit */
    }
}'''

content = content.replace(target_app_main, replacement_app_main)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Reverted .app-main to its original committed state.")
