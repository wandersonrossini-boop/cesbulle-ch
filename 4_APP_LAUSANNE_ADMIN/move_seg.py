import sys

def refactor(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # Move inner segmented control inside pc-column-left
    # It currently starts with <div class="segmented-control" style="margin-bottom:15px; background: #f8fafc...
    # and ends with </div>
    # Then comes <div class="pc-visitor-grid">
    # Then <div class="pc-column-left">
    
    seg_start = html.find('<!-- INNER SEGMENTED CONTROL (MOBILE VIEW) -->')
    if seg_start != -1:
        # Find end of segmented control div
        # it has 3 divs? No, it's <div class="segmented-control"...> <button> <button> </div>
        # Let's just find the exact block using string splitting
        end_str = '</div>\n\n                    <div class="pc-visitor-grid">\n                        <!-- LEFT COLUMN: RAPID CAPTURE (NOVO VISITANTE) -->\n                        <div class="pc-column-left">'
        idx = html.find(end_str)
        if idx != -1:
            # We found the transition between segmented control and pc-column-left
            # Let's extract the segmented control
            seg_end = idx + len('</div>')
            seg_block = html[seg_start:seg_end]
            
            # Remove it from original position
            html = html[:seg_start] + html[seg_end:]
            
            # Insert inside pc-column-left
            insert_str = '<div class="pc-column-left">'
            insert_idx = html.find(insert_str, seg_start) # after we removed it, we find the new pos
            if insert_idx != -1:
                html = html[:insert_idx + len(insert_str)] + '\n                            ' + seg_block + html[insert_idx + len(insert_str):]
                
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Segmented control moved")

refactor('recepcao_v2.html')
