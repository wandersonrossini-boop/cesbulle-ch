# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\presentation\ContributorController.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import re
content = re.sub(r'@PutMapping\s*\(\s*"/{id}"\s*\)\s*public ResponseEntity<\?> delete', r'@DeleteMapping("/{id}")\n    public ResponseEntity<?> delete', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
