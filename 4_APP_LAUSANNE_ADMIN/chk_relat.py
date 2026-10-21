with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()
if "nav-relatorios" in content:
    print("Relatorios menu item is still there!")
else:
    print("Relatorios menu item removed successfully.")
