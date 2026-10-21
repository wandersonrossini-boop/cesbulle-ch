import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Add message listener to index.html
script_target = '''        function logout() { 
            localStorage.removeItem('current_module');
            AuthManager.logout(); 
            location.reload(); 
        }'''

script_replace = '''        function logout() { 
            localStorage.removeItem('current_module');
            AuthManager.logout(); 
            location.reload(); 
        }

        // Listen for navigation messages from iframes (e.g. Recepcao returning home)
        window.addEventListener('message', (event) => {
            if (event.data === 'go_home') {
                localStorage.removeItem('current_module');
                document.getElementById('app-container').style.display = 'none';
                document.getElementById('app-header').style.display = 'none';
                
                // Keep auth intact, just show the module selection again
                showLoginView();
            }
        });'''

content = content.replace(script_target, script_replace)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Listener added")
