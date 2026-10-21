import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

js_target = '''        function setTab(t) {
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
        }'''

js_replacement = '''        function updateMobileEscalaButton() {
            const trigger = document.querySelector('.mobile-escala-trigger');
            if(!trigger) return;
            const colE = document.getElementById('col-e');
            if(colE && colE.classList.contains('active')) {
                trigger.innerHTML = '<i class="fas fa-times"></i> Fechar Escala';
            } else {
                trigger.innerHTML = '<i class="fas fa-list-ul"></i> Escala de Culto';
            }
        }

        function setTab(t) {
            const col = document.getElementById('col-'+t);
            if (window.innerWidth <= 900 && col.classList.contains('active')) {
                col.classList.remove('active');
                document.getElementById('btn-'+t).classList.remove('active');
                updateMobileEscalaButton();
                return;
            }
            document.querySelectorAll('.stat-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.feed-col').forEach(c => c.classList.remove('active'));
            document.getElementById('btn-'+t).classList.add('active');
            col.classList.add('active');
            updateMobileEscalaButton();
        }

        function toggleMobileEscala() {
            const col = document.getElementById('col-e');
            if (col.classList.contains('active')) {
                col.classList.remove('active');
                document.getElementById('btn-e').classList.remove('active');
                updateMobileEscalaButton();
            } else {
                setTab('e');
            }
        }'''

content = content.replace(js_target, js_replacement)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("JS updated successfully")
