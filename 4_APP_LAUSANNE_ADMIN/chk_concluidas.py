with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

if "Concluída em" in content and "fa-check-circle" not in content:
    print("Success: concluidas replaced.")
else:
    print("Failed replacing concluidas.")
    for line in content.split('\n'):
        if "Conclu" in line and "fa-check-circle" in line:
            print("Found: " + line)
