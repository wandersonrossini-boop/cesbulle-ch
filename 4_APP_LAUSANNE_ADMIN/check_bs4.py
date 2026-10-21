from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

soup = BeautifulSoup(content, 'html.parser')
container = soup.find('div', class_='container')
if container:
    children = container.find_all(recursive=False)
    for c in children:
        if c.name == 'div':
            print(f"Child div id={c.get('id')} class={c.get('class')}")
else:
    print("Container not found")

