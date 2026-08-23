# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\members_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

replacement = """
                contributor.hasMovements 
                ? IconButton(
                    icon: const Icon(Icons.block, size: 18),
                    color: Colors.orange,
                    tooltip: 'Desativar (Possui lançamentos)',
                    onPressed: () => _confirmDelete(contributor),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: AppTheme.excludeRed,
                    tooltip: 'Excluir',
                    onPressed: () => _confirmDelete(contributor),
                  ),
"""
content = content.replace("""                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppTheme.excludeRed,
                  tooltip: 'Desativar',
                  onPressed: () => _confirmDelete(contributor),
                ),""", replacement)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
