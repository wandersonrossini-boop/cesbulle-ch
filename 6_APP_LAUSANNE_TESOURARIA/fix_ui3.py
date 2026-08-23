# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\admin_users_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import re
# find the IconButton block
start = content.find('IconButton(')
# we just rewrite the end of the file from IconButton
if start != -1:
    new_tail = """IconButton(
                      icon: const Icon(Icons.block, color: AppTheme.excludeRed),
                      tooltip: 'Desativar Acesso',
                      onPressed: () => _revokeUser(u),
                    ),
          ),
        );
      },
    );
  }
}
"""
    content = content[:start] + new_tail
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
        print("Fixed tail")
