# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\services\movements_api_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("static const String baseUrl = 'http://localhost:8080/api/movements';", "static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api') + '/movements';")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
