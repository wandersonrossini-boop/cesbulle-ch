import sys
from bs4 import BeautifulSoup

def refactor(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()
    
    soup = BeautifulSoup(html, 'html.parser')
    
    # Move visitor-sub-exist to pc-column-left
    col_left = soup.find('div', class_='pc-column-left')
    sub_exist = soup.find('div', id='visitor-sub-exist')
    
    if col_left and sub_exist:
        # Extract sub_exist and append it to col_left
        sub_exist.extract()
        col_left.append(sub_exist)
    
    # Ensure mobile-only-segmented is just "segmented-control" without hiding on PC
    # Wait, if we want NOVO/JA VISITOU to be toggleable on PC, we need to remove mobile-only-segmented
    # or ensure it's not display:none on PC.
    seg_control = soup.find('div', class_='mobile-only-segmented')
    if seg_control:
        seg_control['class'] = [c for c in seg_control['class'] if c != 'mobile-only-segmented']
        
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(str(soup))
    print("DOM restructured")

refactor('recepcao_v2.html')
