import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

js_code = '''
        function openEscalaMobile() {
            document.getElementById('modal-mais').style.display='none';
            setTab('e');
            // Hide topbar explicitly on mobile
            if(window.innerWidth <= 900) {
                document.querySelector('.topbar').style.display = 'none';
            }
        }
        function closeEscalaMobile() {
            document.getElementById('col-e').classList.remove('active');
            // Show topbar again
            if(window.innerWidth <= 900) {
                document.querySelector('.topbar').style.display = 'flex';
                // Switch back to Visitantes by default when closing escala
                setTab('v'); 
            }
        }

        // Clean up toggleMobileEscala and updateMobileEscalaButton
'''

# Remove updateMobileEscalaButton and toggleMobileEscala from previous code
pattern1 = re.compile(r'function updateMobileEscalaButton\(\) \{.*?\n        \}', re.DOTALL)
content = pattern1.sub('', content)

pattern2 = re.compile(r'function toggleMobileEscala\(\) \{.*?\n        \}', re.DOTALL)
content = pattern2.sub('', content)

# modify setTab slightly
setTab_target = '''        function setTab(t) {
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
            
        }'''

setTab_replacement = '''        function setTab(t) {
            const col = document.getElementById('col-'+t);
            if(t !== 'e' && window.innerWidth <= 900) {
                document.querySelector('.topbar').style.display = 'flex';
            }
            
            document.querySelectorAll('.stat-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.feed-col').forEach(c => c.classList.remove('active'));
            document.getElementById('btn-'+t).classList.add('active');
            col.classList.add('active');
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
        }
'''
content = content.replace(setTab_target, setTab_replacement)

# Initialize with 'v' on mobile
init_target = '''        window.addEventListener('DOMContentLoaded', () => {
            if (window.innerWidth <= 900) {
                document.getElementById('btn-e').classList.remove('active');
                document.getElementById('col-e').classList.remove('active');
            }
        });'''
init_replace = '''        window.addEventListener('DOMContentLoaded', () => {
            if (window.innerWidth <= 900) {
                setTab('v');
            }
        });'''
content = content.replace(init_target, init_replace)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("JS updated")
