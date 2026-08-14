import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const CMELausanneApp());
}

class CMELausanneApp extends StatefulWidget {
  const CMELausanneApp({super.key});

  @override
  State<CMELausanneApp> createState() => _CMELausanneAppState();
}

class _CMELausanneAppState extends State<CMELausanneApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (token != null && rememberMe) {
      setState(() => _isLoggedIn = true);
    } else {
      // Clear token if we shouldn't remember
      if (!rememberMe) {
        await prefs.remove('jwt_token');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'CME Lausanne MVP',
      theme: AppTheme.lightTheme,
      home: _isLoggedIn ? const DashboardScreen() : const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
