with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('class="mobile-header-only" style="display:none; justify-content:space-between;', 'class="mobile-header-only" style="justify-content:space-between;')

css_append = '''
        .mobile-header-only { display: none; }
        @media (max-width: 900px) {
            .mobile-header-only { display: flex !important; }
        }
'''

content = content.replace('/* Custom Styles */', '/* Custom Styles */' + css_append)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed mobile header CSS.")
