from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

soup = BeautifulSoup(content, 'html.parser')

services = soup.find(id='tab-services')
if services:
    parent = services.parent
    print(f"Parent of tab-services: {parent.name} id={parent.get('id')} class={parent.get('class')}")
    parent2 = parent.parent
    if parent2:
        print(f"Grandparent: {parent2.name} id={parent2.get('id')} class={parent2.get('class')}")
