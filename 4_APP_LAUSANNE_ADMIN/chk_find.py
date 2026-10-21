import os
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.js') or file.endswith('.html'):
            with open(os.path.join(root, file), 'r', encoding='utf-8', errors='ignore') as f:
                if 'onAuthStateChanged' in f.read():
                    print(file)
