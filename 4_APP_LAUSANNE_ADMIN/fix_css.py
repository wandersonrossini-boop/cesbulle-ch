with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

css_append = '''
        .mobile-header-only { display: none; }
        @media (max-width: 900px) {
            .mobile-header-only { display: flex !important; }
        }
'''

content = content.replace('</style>', css_append + '</style>', 1)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("CSS injected.")
