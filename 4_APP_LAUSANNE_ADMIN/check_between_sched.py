import re
from bs4 import BeautifulSoup

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's find the literal text between tab-schedule and tab-services
start = content.find('id="wizard-step-4"')
end = content.find('id="tab-services"')
print(content[start:end])

