# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\admin_users_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
"""                  : IconButton(
                    icon: const Icon(Icons.block, color: AppTheme.excludeRed),
                    tooltip: 'Desativar Acesso',
                    onPressed: () => _revokeUser(u),
                  ),
                  ),""",
"""                  : IconButton(
                    icon: const Icon(Icons.block, color: AppTheme.excludeRed),
                    tooltip: 'Desativar Acesso',
                    onPressed: () => _revokeUser(u),
                  ),
            ),"""
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
