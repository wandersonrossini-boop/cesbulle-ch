import sys

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # Fix inline switchCheckinMode selector
    old_code = "document.querySelectorAll('#tab-checkin .segment-btn').forEach(b => b.classList.remove('active'));"
    new_code = "document.querySelectorAll('.sidebar-menu .segment-btn, #tab-checkin .segment-btn').forEach(b => b.classList.remove('active'));"
    html = html.replace(old_code, new_code)
    
    # Also fix any other references to segment-btn in switchCheckinMode
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Patched successfully")

patch_file('recepcao_v2.html')
