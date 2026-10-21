from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

soup = BeautifulSoup(content, 'html.parser')
tab_schedule = soup.find(id='tab-schedule')

print(f"Parent of tab-schedule: {tab_schedule.parent.name} class={tab_schedule.parent.get('class')}")
