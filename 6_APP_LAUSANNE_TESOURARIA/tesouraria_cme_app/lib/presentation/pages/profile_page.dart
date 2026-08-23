import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../services/user_api_service.dart';
import '../../core/theme.dart';
import '../widgets/app_sidebar_drawer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserApiService _apiService = UserApiService();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _obscurePass = true;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  AppUser? _user;
  String? _base64Avatar;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = await _apiService.getMyProfile();
      setState(() {
        _user = user;
        _nameCtrl.text = user.name;
        _base64Avatar = user.avatarBase64;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, maxHeight: 300);
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final resized = img.copyResize(image, width: 150, height: 150);
        final jpegBytes = img.encodeJpg(resized, quality: 60);
        setState(() {
          _base64Avatar = base64Encode(jpegBytes);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    
    if (_passCtrl.text.isNotEmpty && _passCtrl.text != _passConfirmCtrl.text) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('As senhas não coincidem!'), backgroundColor: AppTheme.excludeRed));
      return;
    }
    setState(() => _isSaving = true);
    
    try {
      await _apiService.updateMyProfile(_nameCtrl.text.trim(), _passCtrl.text.trim(), _base64Avatar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado!')));
        _passCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.excludeRed));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          const AppSidebarDrawer(activeRoute: 'perfil', permanent: true),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'perfil'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
      body: body,
    );
  }

  Widget _buildContent(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 24, vertical: isDesktop ? 32 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CONFIGURAÇÕES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Text('Meu Perfil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 32),
              
              // Avatar Config
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _base64Avatar != null ? MemoryImage(base64Decode(_base64Avatar!)) : null,
                        child: _base64Avatar == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: _user?.username),
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Login (Nome de Usuário)', border: OutlineInputBorder(), fillColor: Color(0xFFF1F5F9), filled: true),
              ),
              const SizedBox(height: 16),
              
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: 'CME Lausanne'),
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Congregação', border: OutlineInputBorder(), fillColor: Color(0xFFF1F5F9), filled: true),
              ),
              const SizedBox(height: 32),
              const Text('SEGURANÇA', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Nova Senha (deixe em branco para não alterar)', 
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passConfirmCtrl,
                obscureText: _obscurePass,
                decoration: const InputDecoration(labelText: 'Confirmar Nova Senha', border: OutlineInputBorder()),
              ),

              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
