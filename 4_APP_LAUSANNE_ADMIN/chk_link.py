with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    l = line.lower()
    if "whatsapp" in l or "qr code" in l or "online" in l:
        print(f"Line {i+1}: {line.strip()}")
