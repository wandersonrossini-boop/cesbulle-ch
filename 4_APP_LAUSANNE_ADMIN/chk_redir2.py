with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "session_role" in line or "role" in line.lower() and "redirect" in line.lower():
        print(f"{i+1}: {line.strip()}")
