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

  
  Future<void> _deleteUser(AppUser user) async {
    try {
      await _apiService.deleteUser(user.id);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitação de ${user.name} rejeitada.')));
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
                ? Row(
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
                  )
                : TextButton.icon(
                      icon: const Icon(Icons.block, color: AppTheme.excludeRed, size: 18),
                      label: const Text('Desativar acesso', style: TextStyle(color: AppTheme.excludeRed)),
                      onPressed: () => _revokeUser(u),
                    ),
          ),
        );
      },
    );
  }
}
