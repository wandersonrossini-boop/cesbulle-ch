with open('js/auth-manager.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "integracao" in line or "pin" in line.lower() or "role" in line.lower():
        print(f"Line {i+1}: {line.strip()}")
