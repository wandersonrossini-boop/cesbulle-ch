import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix background
content = content.replace('background: var(--bg-dark);', 'background: var(--bg);')

# Remove modal-mais from PDF string
pdf_modal_pattern = re.compile(r'<\/script>\s*\\n\s*<\/body>\s*\\n\s*<div id="modal-mais" class="modal-mais">.*?<\/div>\s*\\n<\/div>\s*\\n<\/body>', re.DOTALL)
# wait, my previous replacement was content.replace('</body>', modal_html + '\n</body>')
# So the PDF string has:
#                    <\/script>
#                \n    <div id="modal-mais" class="modal-mais">...</div>\n</body>
#                </html>
# Let's just find the first modal-mais and remove it if it's inside the PDF string.

first_modal = content.find('<div id="modal-mais" class="modal-mais">')
last_modal = content.rfind('<div id="modal-mais" class="modal-mais">')
if first_modal != last_modal:
    # We have duplicates! Let's slice the string to remove the first one.
    # The first one ends at the next </div>\n    </div> (the end of modal_html)
    end_first = content.find('</div>\n    </div>', first_modal) + len('</div>\n    </div>')
    # wait, the modal has nested divs. 
    # modal_html ends with </div>\n    </div>\n
    end_first = content.find('Sair</div>\n        </div>\n    </div>', first_modal) + len('Sair</div>\n        </div>\n    </div>')
    content = content[:first_modal] + content[end_first:]

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Duplicates removed and bg fixed")
