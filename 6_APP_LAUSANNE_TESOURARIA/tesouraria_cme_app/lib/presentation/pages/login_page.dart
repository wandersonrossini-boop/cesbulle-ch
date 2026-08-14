import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../services/auth_api_service.dart';
import '../../core/theme.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthApiService();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _showColdStartNotice = false;
  String? _errorMessage;
  Timer? _coldStartTimer;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _coldStartTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showColdStartNotice = false;
    });

    _coldStartTimer?.cancel();
    _coldStartTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _isLoading) {
        setState(() {
          _showColdStartNotice = true;
        });
      }
    });

    try {
      final errorMsg = await _authService.login(
        _usernameController.text,
        _passwordController.text,
      );

      _coldStartTimer?.cancel();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _showColdStartNotice = false;
        });
      }

      if (errorMsg == null) {
        // Success
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);
        
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = errorMsg;
          });
        }
      }
    } catch (_) {
      _coldStartTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showColdStartNotice = false;
          _errorMessage = 'Falha ao conectar com o servidor. Tente novamente.';
        });
      }
    }
  }

  void _showRegisterDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isRegistering = false;
    String? modalError;
    String? base64Avatar;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Solicitar Acesso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Preencha seus dados. O acesso só será liberado após a aprovação do Administrador.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, maxHeight: 300);
                      if (xfile != null) {
                        final bytes = await xfile.readAsBytes();
                        // Compress aggressively
                        final image = img.decodeImage(bytes);
                        if (image != null) {
                          final resized = img.copyResize(image, width: 150, height: 150);
                          final jpegBytes = img.encodeJpg(resized, quality: 60);
                          setModalState(() {
                            base64Avatar = base64Encode(jpegBytes);
                          });
                        }
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: base64Avatar != null ? MemoryImage(base64Decode(base64Avatar!)) : null,
                      child: base64Avatar == null
                          ? const Icon(Icons.camera_alt, color: Colors.grey, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(labelText: 'Nome de Usuário', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                  ),
                  if (modalError != null) ...[
                    const SizedBox(height: 12),
                    Text(modalError!, style: const TextStyle(color: AppTheme.excludeRed, fontSize: 13)),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isRegistering ? null : () => Navigator.pop(ctx),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: isRegistering
                    ? null
                    : () async {
                        if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                          setModalState(() => modalError = 'Preencha todos os campos.');
                          return;
                        }
                        setModalState(() {
                          isRegistering = true;
                          modalError = null;
                        });

                        final err = await _authService.register(
                            nameCtrl.text.trim(), userCtrl.text.trim(), passCtrl.text.trim(), base64Avatar);

                        if (err != null) {
                          setModalState(() {
                            isRegistering = false;
                            modalError = err;
                          });
                        } else {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Solicitação enviada! Aguarde a aprovação.')),
                            );
                          }
                        }
                      },
                child: isRegistering
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('ENVIAR'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Dark blue elegant background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF031224), Color(0xFF06203D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo / Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Titles
                  const Text(
                    "CME Lausanne",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "T E S O U R A R I A",
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF1E3A5F), thickness: 1, indent: 40, endIndent: 40),
                  const SizedBox(height: 32),

                  // White Card
                  Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), // slightly off-white for a cleaner look
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // USUÁRIO
                        const Text(
                          "USUÁRIO",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Informe seu usuário',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF475569), size: 22),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // SENHA
                        const Text(
                          "SENHA",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Informe sua senha',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF475569), size: 22),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF475569),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Lembrar-me e Esqueci minha senha
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: AppTheme.primaryGreen,
                                    side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Lembrar-me",
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: const Text("Esqueci minha senha", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    content: const Text(
                                      "Por razões de segurança, a redefinição de senha deve ser solicitada diretamente ao Administrador do Sistema ou à Secretaria CME.",
                                      style: TextStyle(color: Color(0xFF475569)),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("ENTENDIDO"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text(
                                "Esqueci a senha",
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Error Message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.excludeRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.excludeRed, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppTheme.excludeRed, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F6030), // Dark green matching the mockup
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Request Access Button (Keeping functionality)
                  TextButton(
                    onPressed: () => _showRegisterDialog(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text(
                      "Novo Tesoureiro? Solicitar Acesso",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  
                  if (_showColdStartNotice) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Conectando ao servidor. A primeira conexão pode levar alguns segundos...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Footer
                  Text(
                    "CME Lausanne  •  Tesouraria\nv1.0.0",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
