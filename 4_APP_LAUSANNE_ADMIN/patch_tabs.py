import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix Eventos
target_events = '<div id="tab-events" class="tab-section" style="display:none; height: 85vh;">'
replacement_events = '<div id="tab-events" class="tab-section" style="display:none; height: 85vh; margin-top: -40px;">'
content = content.replace(target_events, replacement_events)

# Fix Servir (normalize to the container)
target_services = '''<div id="tab-services" class="tab-section" style="display:none;">

        <div style="text-align:center; margin-bottom:20px; margin-top:-220px;">'''
replacement_services = '''<div id="tab-services" class="tab-section" style="display:none; margin-top: -220px;">

        <div style="text-align:center; margin-bottom:20px; margin-top: 0;">'''
content = content.replace(target_services, replacement_services)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("HTML ajustado!")
