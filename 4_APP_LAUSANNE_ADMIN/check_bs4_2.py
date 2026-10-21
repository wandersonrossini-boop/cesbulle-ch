from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

soup = BeautifulSoup(content, 'html.parser')

main = soup.find('main', class_='app-main')
if not main:
    print("Main not found")
else:
    print("Children of app-main:")
    for child in main.find_all(recursive=False):
        if child.name:
            print(f" - {child.name}: id={child.get('id')} class={child.get('class')}")

print("\n---")
container = soup.find('div', class_='container')
if container:
    print("Children of container:")
    for child in container.find_all(recursive=False):
        if child.name:
            print(f" - {child.name}: id={child.get('id')} class={child.get('class')}")
