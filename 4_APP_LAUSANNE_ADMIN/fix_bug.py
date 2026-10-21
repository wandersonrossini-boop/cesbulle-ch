import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix onAuthSuccess priority and onAuthLogout
old_success = """        window.onAuthSuccess = (user, role) => {

            const savedModule = localStorage.getItem('current_module');
            let targetModule = savedModule || currentRole || role;"""

new_success = """        window.onAuthSuccess = (user, role) => {

            const savedModule = localStorage.getItem('current_module');
            // Prioritize currentRole if user just clicked a card
            let targetModule = currentRole || savedModule || role;"""

content = content.replace(old_success, new_success)

old_logout = """        window.onAuthLogout = () => {

            showLoginView();
        };"""

new_logout = """        window.onAuthLogout = () => {
            localStorage.removeItem('current_module');
            currentRole = null;
            showLoginView();
        };"""

content = content.replace(old_logout, new_logout)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed index.html routing bug.")
