with open('js/auth-manager.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "redirect" in line or "postMessage" in line or "window.location" in line:
        print(f"{i+1}: {line.strip()}")
