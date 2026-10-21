with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

if "Concluir</button>" in content and "Marcar Conclu" not in content:
    print("Success")
else:
    print("Failure, string wasn't completely replaced. Checking what's left...")
    for line in content.split('\n'):
        if "Marcar Conclu" in line or "border-left:4px" in line:
            print(line)
