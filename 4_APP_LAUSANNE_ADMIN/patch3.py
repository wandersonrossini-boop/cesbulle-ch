import sys

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        js = f.read()

    # Fix external switchCheckinMode selector
    old_code = "btn.parentNode.querySelectorAll('.segment-btn').forEach(b => b.classList.remove('active'));"
    new_code = "document.querySelectorAll('.sidebar-menu .segment-btn, .segmented-control .segment-btn').forEach(b => b.classList.remove('active'));"
    js = js.replace(old_code, new_code)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(js)
    print("Patched JS successfully")

patch_file('js/reception_kids_logic.js')
