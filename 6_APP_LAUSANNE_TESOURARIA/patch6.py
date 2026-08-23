# -*- coding: utf-8 -*-
import sys

path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\expenses_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# We need to import the AttachmentUploader at the top
import_str = "import '../widgets/attachment_uploader.dart';\n"
if "attachment_uploader.dart" not in content:
    idx = content.find("import 'package:flutter/material.dart';")
    if idx != -1:
        content = content[:idx] + import_str + content[idx:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Import added")
