# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\presentation\ContributorController.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('@PutMapping("/{id}")\n        @DeleteMapping("/{id}")', '@DeleteMapping("/{id}")')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
