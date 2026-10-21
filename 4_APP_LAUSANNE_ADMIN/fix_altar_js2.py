import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# I will use regex to find and replace setTab
pattern = re.compile(r'function setTab\(t\) \{.*?\n        \}', re.DOTALL)
replacement = '''function setTab(t) {
            const col = document.getElementById('col-'+t);
            if(t !== 'e' && window.innerWidth <= 900) {
                document.querySelector('.topbar').style.display = 'flex';
            }
            
            document.querySelectorAll('.stat-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.feed-col').forEach(c => c.classList.remove('active'));
            if(document.getElementById('btn-'+t)) document.getElementById('btn-'+t).classList.add('active');
            if(col) col.classList.add('active');
        }

        function toggleMaisMenu() {
            const modal = document.getElementById('modal-mais');
            if(modal.style.display === 'flex') {
                modal.style.display = 'none';
            } else {
                modal.style.display = 'flex';
            }
        }

        function openEscalaMobile() {
            document.getElementById('modal-mais').style.display='none';
            setTab('e');
            if(window.innerWidth <= 900) {
                document.querySelector('.topbar').style.display = 'none';
            }
        }
        function closeEscalaMobile() {
            if(window.innerWidth <= 900) {
                document.querySelector('.topbar').style.display = 'flex';
                setTab('v'); 
            }
        }'''

content = pattern.sub(replacement, content)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("JS completely fixed")
