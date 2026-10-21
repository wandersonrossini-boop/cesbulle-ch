with open('gabinete.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "async function loadPeopleList()" in line:
        for j in range(i, i+25):
            print(lines[j].strip())
        break
