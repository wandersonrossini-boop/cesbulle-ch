# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\services\contributor_api_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("final bool active;", "final bool active;\n  final bool hasMovements;")
content = content.replace("required this.active,", "required this.active,\n    this.hasMovements = false,")
content = content.replace("active: json['active'] ?? true,", "active: json['active'] ?? true,\n      hasMovements: json['hasMovements'] ?? false,")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
