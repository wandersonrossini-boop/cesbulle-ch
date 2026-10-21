from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

soup = BeautifulSoup(content, 'html.parser')
services = soup.find(id='tab-services')

if services:
    parent = services.parent
    print(f"Parent id: {parent.get('id')}")
