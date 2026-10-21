import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update onclick in HTML
content = content.replace('''<div class="mobile-escala-trigger" onclick="setTab('e')">''', '''<div class="mobile-escala-trigger" onclick="toggleMobileEscala()">''')

# 2. Add the JS functions
js_code = '''
        function setTab(t) {
            const col = document.getElementById('col-'+t);
            if (window.innerWidth <= 900 && col.classList.contains('active')) {
                col.classList.remove('active');
                document.getElementById('btn-'+t).classList.remove('active');
                return;
            }
            document.querySelectorAll('.stat-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.feed-col').forEach(c => c.classList.remove('active'));
            document.getElementById('btn-'+t).classList.add('active');
            col.classList.add('active');
        }

        function toggleMobileEscala() {
            const col = document.getElementById('col-e');
            if (col.classList.contains('active')) {
                col.classList.remove('active');
                document.getElementById('btn-e').classList.remove('active');
            } else {
                setTab('e');
            }
        }

        window.addEventListener('DOMContentLoaded', () => {
            if (window.innerWidth <= 900) {
                document.getElementById('btn-e').classList.remove('active');
                document.getElementById('col-e').classList.remove('active');
            }
        });
'''

# Replace original setTab
pattern = re.compile(r'function setTab\(t\) \{.*?\n        \}', re.DOTALL)
content = pattern.sub(js_code.strip(), content)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("JS updated")
