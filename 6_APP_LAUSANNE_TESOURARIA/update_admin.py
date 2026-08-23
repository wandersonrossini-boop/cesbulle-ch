# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\admin_users_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '''subtitle: Text('@${u.username} • ${u.role}'),''',
    '''subtitle: Text('@${u.username} • ${u.role == 'ADMIN' ? 'Administrador' : 'Tesoureiro'}'),'''
)

content = content.replace(
    '''tooltip: 'Revogar Acesso',
                    onPressed: () => _revokeUser(u),''',
    '''tooltip: 'Desativar Acesso',
                    onPressed: () => _revokeUser(u),'''
)

# Replace the trailing widget for pending users with a Row of Aprovar and Rejeitar
new_trailing = """trailing: isPending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _deleteUser(u),
                        child: const Text('REJEITAR', style: TextStyle(color: AppTheme.excludeRed)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _approveUser(u),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        child: const Text('APROVAR', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.block, color: AppTheme.excludeRed),
                    tooltip: 'Desativar Acesso',
                    onPressed: () => _revokeUser(u),
                  ),"""

# Let's extract the exact old trailing string to replace
old_trailing_start = content.find('trailing: isPending')
old_trailing_end = content.find('),', content.find('onPressed: () => _revokeUser(u)')) + 2

if old_trailing_start != -1 and old_trailing_end != -1:
    content = content[:old_trailing_start] + new_trailing + content[old_trailing_end:]
else:
    print("Could not find trailing to replace")

# Add _deleteUser method
if 'Future<void> _deleteUser' not in content:
    delete_func = """
  Future<void> _deleteUser(AppUser user) async {
    try {
      await _apiService.deleteUser(user.id);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitação de ${user.name} rejeitada.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }
"""
    approve_func_start = content.find('Future<void> _approveUser')
    if approve_func_start != -1:
        content = content[:approve_func_start] + delete_func + content[approve_func_start:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated admin_users_page.dart")
