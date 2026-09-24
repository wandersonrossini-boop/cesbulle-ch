import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Adjust vertical spacing: push content lower on large screens
content = content.replace('.app-main { padding: 30px 20px !important; }', 
'''.app-main { 
    padding: 30px 20px !important; 
    min-height: calc(100vh - 180px); /* Account for header and footer */
    display: flex;
    flex-direction: column;
    justify-content: flex-start; /* Default for mobile */
}
@media(min-width: 900px) {
    .app-main {
        justify-content: center; /* Center vertically on large screens */
        padding-top: 5vh !important; /* Push it down a bit */
    }
}
''')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Vertical layout patched.")
