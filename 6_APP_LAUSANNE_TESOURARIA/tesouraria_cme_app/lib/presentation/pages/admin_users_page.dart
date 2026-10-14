import 'package:flutter/material.dart';
import '../../services/user_api_service.dart';
import '../../core/theme.dart';
import '../widgets/app_sidebar_drawer.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final UserApiService _apiService = UserApiService();
  List<AppUser> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final users = await _apiService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  
  Future<void> _showResetPasswordDialog(AppUser user) async {
    final controller = TextEditingController();
    bool obscure = true;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: AppTheme.institutionalBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Alterar Senha de ${user.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Defina uma nova senha para o utilizador @${user.username}:', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Nova Senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 4) {
                      return 'A senha deve ter no mínimo 4 caracteres.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx);
                  try {
                    await _apiService.resetPassword(user.id, controller.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Senha de ${user.name} alterada com sucesso!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao alterar senha: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.institutionalBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salvar Nova Senha'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(AppUser user) async {
    if (user.username.toLowerCase() == 'pastor' || user.role.toUpperCase() == 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A conta administrativa principal não pode ser excluída.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.excludeRed),
            SizedBox(width: 8),
            Text('Excluir Conta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Deseja realmente excluir permanentemente a conta de ${user.name} (@${user.username})?\nEsta ação não poderá ser desfeita.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.excludeRed, foregroundColor: Colors.white),
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteUser(user);
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.username.toLowerCase() == 'pastor' || user.role.toUpperCase() == 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A conta administrativa principal não pode ser excluída.')));
      return;
    }
    try {
      await _apiService.deleteUser(user.id);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conta de ${user.name} removida com sucesso.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _approveUser(AppUser user) async {
    try {
      await _apiService.approveUser(user.id);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} aprovado!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _revokeUser(AppUser user) async {
    if (user.username.toLowerCase() == 'pastor' || user.role.toUpperCase() == 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A conta administrativa principal não pode ser revogada.')));
      return;
    }
    try {
      await _apiService.revokeUser(user.id);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acesso de ${user.name} revogado!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else {
      body = _buildContent(isDesktop);
    }

    if (isDesktop) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSidebarDrawer(activeRoute: 'admin_users', permanent: true),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'admin_users'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppTheme.institutionalBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Administração de Tesoureiros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
      body: body,
    );
  }

  Widget _buildContent(bool isDesktop) {
    final pending = _users.where((u) => !u.isAuthorized).toList();
    final active = _users.where((u) => u.isAuthorized).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 24, vertical: isDesktop ? 32 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ADMINISTRAÇÃO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Text('Tesoureiros e Acessos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 32),
              
              if (pending.isNotEmpty) ...[
                const Text('APROVAÇÕES PENDENTES', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.excludeRed)),
                const SizedBox(height: 12),
                _buildUserList(pending, isPending: true),
                const SizedBox(height: 32),
              ],

              const Text('TESOUREIROS ATIVOS', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              const SizedBox(height: 12),
              _buildUserList(active, isPending: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List<AppUser> list, {required bool isPending}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final u = list[index];
        final isMasterAdmin = u.username.toLowerCase() == 'pastor' || u.role.toUpperCase() == 'ADMIN';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.institutionalBlue.withOpacity(0.1),
              child: Text(
                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.institutionalBlue),
              ),
            ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('@${u.username} • ${u.role == 'ADMIN' ? 'Administrador' : 'Tesoureiro'}'),
            trailing: isPending
                ? (isMasterAdmin
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'Conta Protegida',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.institutionalBlue,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _deleteUser(u),
                            child: const Text('Rejeitar', style: TextStyle(color: AppTheme.excludeRed)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _approveUser(u),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                            child: const Text('Aprovar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ))
                : (isMasterAdmin
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text(
                          'Conta Protegida',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.institutionalBlue,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lock_reset, color: AppTheme.institutionalBlue, size: 20),
                            tooltip: 'Alterar senha',
                            onPressed: () => _showResetPasswordDialog(u),
                          ),
                          IconButton(
                            icon: const Icon(Icons.block, color: Color(0xFFEA580C), size: 20),
                            tooltip: 'Desativar acesso',
                            onPressed: () => _revokeUser(u),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.excludeRed, size: 20),
                            tooltip: 'Excluir conta',
                            onPressed: () => _confirmDeleteUser(u),
                          ),
                        ],
                      )),
          ),
        );
      },
    );
  }
}
