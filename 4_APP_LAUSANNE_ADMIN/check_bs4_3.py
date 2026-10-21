from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

soup = BeautifulSoup(content, 'html.parser')

main = soup.find('main', class_='app-main')
if main:
    print("Siblings AFTER app-main:")
    for sibling in main.find_next_siblings():
        if sibling.name:
            print(f" - {sibling.name}: id={sibling.get('id')} class={sibling.get('class')}")
