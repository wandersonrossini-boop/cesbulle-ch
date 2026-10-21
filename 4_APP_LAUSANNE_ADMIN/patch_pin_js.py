import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''            currentRole = role;
            document.getElementById('role-selection').style.display='none';
            document.getElementById('pin-screen').style.display='flex';'''

replace = '''            currentRole = role;
            document.getElementById('role-selection').style.display='none';
            document.getElementById('pin-screen').style.display='flex';
            
            const roleDisplayNames = {
                'reception': 'ACESSO À RECEPÇÃO',
                'kids': 'ACESSO À ÁREA INFANTIL',
                'altar': 'ACESSO AO ALTAR',
                'integracao': 'ACESSO À INTEGRAÇÃO',
                'admin': 'ACESSO À SECRETARIA',
                'gabinete': 'ACESSO AO GABINETE'
            };
            const subtitleDisplayNames = {
                'reception': 'Área de Recepção',
                'kids': 'Ministério Infantil',
                'altar': 'Operação do Culto',
                'integracao': 'Departamento de Integração',
                'admin': 'Administração e Secretaria',
                'gabinete': 'Gabinete Pastoral'
            };
            
            const titleEl = document.getElementById('pin-screen-title');
            if(titleEl) titleEl.innerText = roleDisplayNames[role] || 'ACESSO AO MÓDULO';
            
            const subtextEl = document.getElementById('pin-screen-subtext');
            if(subtextEl) subtextEl.innerText = subtitleDisplayNames[role] || 'CME Lausanne';'''

content = content.replace(target, replace)

# Add keypress listeners at the end of script
target2 = '''    </script>
</body>
</html>'''

replace2 = '''
        // Add Enter key listener for login fields
        document.addEventListener('DOMContentLoaded', () => {
            const handleEnter = (e) => {
                if (e.key === 'Enter') {
                    validatePin();
                }
            };
            const pinInput = document.getElementById('pin-input');
            const emailInput = document.getElementById('email-input');
            const passwordInput = document.getElementById('password-input');
            
            if (pinInput) pinInput.addEventListener('keypress', handleEnter);
            if (emailInput) emailInput.addEventListener('keypress', handleEnter);
            if (passwordInput) passwordInput.addEventListener('keypress', handleEnter);
        });
    </script>
</body>
</html>'''

content = content.replace(target2, replace2)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("JS added")
