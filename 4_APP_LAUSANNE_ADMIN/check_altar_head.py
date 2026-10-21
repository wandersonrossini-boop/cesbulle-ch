import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the real </style> which is before </head>
start = content.find('</style>')
print(content[start-200:start+100])
