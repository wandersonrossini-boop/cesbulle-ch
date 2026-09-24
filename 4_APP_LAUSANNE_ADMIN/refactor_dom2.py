import sys
import re

def refactor(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()
    
    # 1. Extract visitor-sub-exist block
    block_start = html.find('<div id="visitor-sub-exist"')
    if block_start != -1:
        block_end = html.find('<!-- END visitor-sub-exist -->', block_start) + len('<!-- END visitor-sub-exist -->')
        if block_end != -1:
            exist_block = html[block_start:block_end]
            html = html[:block_start] + html[block_end:]
            
            # 2. Insert it just before <!-- END pc-column-left -->
            target_str = '</div> <!-- END pc-column-left -->'
            target_idx = html.find(target_str)
            if target_idx != -1:
                html = html[:target_idx] + exist_block + '\n                            ' + html[target_idx:]
    
    # 3. Remove .mobile-only-segmented class so it shows on PC too
    html = html.replace('mobile-only-segmented', '')
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("DOM restructured")

refactor('recepcao_v2.html')
