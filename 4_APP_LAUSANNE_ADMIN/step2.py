import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the HTML for mobile-escala-trigger
trigger_html = '''            <!-- Mobile Escala Trigger -->
            <div class="mobile-escala-trigger" onclick="toggleMobileEscala()">
                <i class="fas fa-list-ul"></i> Escala de Culto
            </div>'''
content = content.replace(trigger_html, '')

# I will also remove its CSS rule
pattern = re.compile(r'\.mobile-escala-trigger\s*\{[^}]*\}', re.DOTALL)
content = pattern.sub('', content)
pattern2 = re.compile(r'\.mobile-escala-trigger:active\s*\{[^}]*\}', re.DOTALL)
content = pattern2.sub('', content)


with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Trigger removed")
