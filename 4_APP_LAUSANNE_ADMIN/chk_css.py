with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()
if "mobile-header-only { display: none; }" in content:
    print("CSS added.")
else:
    print("CSS NOT added. Let's append before </style>")
