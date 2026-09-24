import sys

def patch_js(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        js = f.read()

    # Find the global switchCheckinMode and inject setTab('checkin') if not present
    old_code = 'window.switchCheckinMode = function (mode, btn) {\n    console.log("Switching mode to:", mode);'
    new_code = 'window.switchCheckinMode = function (mode, btn) {\n    console.log("Switching mode to:", mode);\n    if(typeof window.setTab === "function") window.setTab("checkin");'
    
    if "window.setTab('checkin')" not in js and 'window.setTab("checkin")' not in js:
        js = js.replace(old_code, new_code)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(js)
    print("Patched JS successfully")

patch_js('js/reception_kids_logic.js')
