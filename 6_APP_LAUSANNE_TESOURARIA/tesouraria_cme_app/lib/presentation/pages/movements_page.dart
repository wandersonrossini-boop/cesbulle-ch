import 'package:flutter/material.dart';
import '../../services/auth_api_service.dart';
import '../../services/fechamento_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'login_page.dart';

class MovementItem {
  final String date;
  final String description;
  final String category;
  final String contributor;
  final double amount;
  final bool isIncome;

  MovementItem({
    required this.date,
    required this.description,
    required this.category,
    required this.contributor,
    required this.amount,
    required this.isIncome,
  });
}

class MovementsPage extends StatefulWidget {
  const MovementsPage({super.key});

  @override
  State<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<MovementsPage> {
  final FechamentoApiService _apiService = FechamentoApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<MovementItem> _movements = [];
  String _searchQuery = '';
  String _selectedCategory = 'TODAS';

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final closings = await _apiService.fetchHistorico();
      List<MovementItem> items = [];

      for (var summary in closings) {
        try {
          final detail = await _apiService.fetchClosingDetail(summary.id);

          // Identified entries
          for (var entry in detail.identifiedEntries) {
            items.add(MovementItem(
              date: detail.serviceDate,
              description: 'Lançamento Identificado #${summary.id}',
              category: entry.type.name.toUpperCase(),
              contributor: entry.memberName,
              amount: entry.amount / 100.0,
              isIncome: true,
            ));
          }

          // Unidentified Dizimos
          if (detail.unidentifiedDizimoTotal > 0) {
            items.add(MovementItem(
              date: detail.serviceDate,
              description: 'Dízimo Anônimo (Bandeja)',
              category: 'DÍZIMO',
              contributor: 'Anônimo',
              amount: detail.unidentifiedDizimoTotal,
              isIncome: true,
            ));
          }

          // Unidentified Ofertas
          if (detail.unidentifiedOfertaTotal > 0) {
            items.add(MovementItem(
              date: detail.serviceDate,
              description: 'Oferta Anônima (Bandeja)',
              category: 'OFERTA',
              contributor: 'Anônimo',
              amount: detail.unidentifiedOfertaTotal,
              isIncome: true,
            ));
          }

          // Unidentified Votos
          if (detail.unidentifiedVotoTotal > 0) {
            items.add(MovementItem(
              date: detail.serviceDate,
              description: 'Voto Anônimo (Bandeja)',
              category: 'VOTO',
              contributor: 'Anônimo',
              amount: detail.unidentifiedVotoTotal,
              isIncome: true,
            ));
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _movements = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('UNAUTHORIZED')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sessão expirada. Faça login novamente.'),
                backgroundColor: Color(0xFFDC2626),
                duration: Duration(seconds: 2),
              ),
            );
            await Future.delayed(const Duration(seconds: 2));
            await AuthApiService().logout();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            }
          }
          return;
        } else {
          setState(() {
            _errorMessage = 'Falha ao carregar movimentos: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    }
  }

  List<MovementItem> get _filteredMovements {
    return _movements.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.contributor.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'TODAS' || item.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'movimentos'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Movimentos de Caixa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: _buildBody(context, isDesktop),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    Widget content;

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      content = _buildErrorState();
    } else {
      content = _buildMovementsView(isDesktop);
    }

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSidebarDrawer(activeRoute: 'movimentos', permanent: true),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'Falha ao carregar movimentos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMovements,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsView(bool isDesktop) {
    final filtered = _filteredMovements;
    final totalEntradas = filtered.where((m) => m.isIncome).fold(0.0, (sum, m) => sum + m.amount);
    final totalSaidas = filtered.where((m) => !m.isIncome).fold(0.0, (sum, m) => sum + m.amount);
    final saldo = totalEntradas - totalSaidas;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 24),
              _buildSummaryCards(totalEntradas, totalSaidas, saldo),
              const SizedBox(height: 24),
              _buildFilterAndSearchRow(isDesktop),
              const SizedBox(height: 24),
              _buildMovementsTable(filtered, isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FLUXO DE CAIXA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Movimentos Financeiros',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Extrato completo das entradas e saídas registradas nos fechamentos.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double entradas, double saidas, double saldo) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard('Total Entradas', 'CHF ${entradas.toStringAsFixed(2)}', Icons.arrow_downward_rounded, const Color(0xFF059669)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Total Saídas', 'CHF ${saidas.toStringAsFixed(2)}', Icons.arrow_upward_rounded, const Color(0xFFDC2626)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard('Saldo do Filtro', 'CHF ${saldo.toStringAsFixed(2)}', Icons.account_balance_wallet_outlined, const Color(0xFF1E3A8A)),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchRow(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar por contribuinte ou descrição...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              items: const [
                DropdownMenuItem(value: 'TODAS', child: Text('Todas Categorias', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'DÍZIMO', child: Text('Dízimo', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'OFERTA', child: Text('Oferta', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'VOTO', child: Text('Voto', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovementsTable(List<MovementItem> items, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text('DATA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                Expanded(
                  flex: 3,
                  child: Text('CONTRIBUINTE / DESCRIÇÃO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                SizedBox(
                  width: 70,
                  child: Text('CAT.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                SizedBox(
                  width: 90,
                  child: Text('VALOR', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Nenhum movimento encontrado.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(item.date, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.contributor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                            Text(item.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          item.category.length > 4 ? item.category.substring(0, 4) : item.category,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '${item.isIncome ? '+' : '-'} CHF ${item.amount.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: item.isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
