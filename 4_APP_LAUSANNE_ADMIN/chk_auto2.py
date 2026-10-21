with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "firebase.auth().onAuthStateChanged" in line:
        for j in range(i-5, i+20):
            try:
                print(f"{j+1}: {lines[j].rstrip()}")
            except:
                pass
        break
