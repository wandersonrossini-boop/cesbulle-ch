with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

if "WhatsApp Integration for Visitor" in content:
    print("Success: WhatsApp logic applied.")
else:
    print("Failed to apply WhatsApp logic.")
