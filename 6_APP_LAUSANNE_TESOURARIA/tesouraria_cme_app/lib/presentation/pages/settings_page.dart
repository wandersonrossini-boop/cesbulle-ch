import 'package:flutter/material.dart';
import '../../services/draft_service.dart';
import '../../services/fechamento_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DraftService _draftService = DraftService();
  final FechamentoApiService _apiService = FechamentoApiService();

  bool _isClearingDraft = false;

  Future<void> _clearCurrentDraft() async {
    setState(() => _isClearingDraft = true);
    try {
      await _draftService.clearDraft();
      await _apiService.clearDraftOnServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rascunho de fechamento limpo com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao limpar rascunho: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingDraft = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'configuracoes'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Configurações',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const AppSidebarDrawer(activeRoute: 'configuracoes', permanent: true),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(isDesktop),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: 'Congregação & Moeda',
                        icon: Icons.church_outlined,
                        children: [
                          _buildInfoRow('Congregação', 'CME Lausanne'),
                          _buildInfoRow('Moeda Padrão', 'CHF (Franco Suíço)'),
                          _buildInfoRow('Sub-unidade', 'Rappen (1 CHF = 100 Rappen)'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: 'Manutenção de Dados',
                        icon: Icons.cleaning_services_outlined,
                        children: [
                          const Text(
                            'Caso um fechamento em andamento fique travado ou com dados inconsistentes, você pode redefinir o rascunho.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _isClearingDraft ? null : _clearCurrentDraft,
                              icon: _isClearingDraft
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                              label: const Text('Limpar Rascunho de Fechamento', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: 'Servidor & Sistema',
                        icon: Icons.info_outline,
                        children: [
                          _buildInfoRow('API Backend', 'https://tesouraria-cme-api.onrender.com/api'),
                          _buildInfoRow('Versão do App', '1.2.0 (Release Lausanne)'),
                          _buildInfoRow('Ambiente', 'Produção (Firebase Hosting)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SISTEMA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configurações da Tesouraria',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Parâmetros do aplicativo e manutenção do sistema.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
