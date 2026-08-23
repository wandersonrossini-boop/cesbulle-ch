# -*- coding: utf-8 -*-
import re
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\profile_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add _passConfirmCtrl and _obscurePass
if 'final _passConfirmCtrl' not in content:
    content = content.replace(
        'final _passCtrl = TextEditingController();',
        'final _passCtrl = TextEditingController();\n  final _passConfirmCtrl = TextEditingController();\n  bool _obscurePass = true;'
    )

# Add save check for password match
if '_passConfirmCtrl.text' not in content:
    save_logic = """
    if (_passCtrl.text.isNotEmpty && _passCtrl.text != _passConfirmCtrl.text) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('As senhas não coincidem!'), backgroundColor: AppTheme.excludeRed));
      return;
    }
    setState(() => _isSaving = true);
    """
    content = content.replace('setState(() => _isSaving = true);', save_logic)

# Rebuild UI content
new_password_ui = """
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
"""
# Replace the old password field
content = re.sub(
    r'TextField\(\s*controller: _passCtrl,\s*obscureText: true,\s*decoration: const InputDecoration\(labelText: \'Nova Senha.*?\),\s*\),',
    new_password_ui,
    content,
    flags=re.DOTALL
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated profile_page.dart")
