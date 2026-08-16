import 'package:flutter/material.dart';
import '../../domain/envelope.dart';
import '../../domain/service_closing_history_models.dart';
import '../../services/auth_api_service.dart';
import '../../services/fechamento_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'login_page.dart';

enum ReportPeriod {
  thisMonth('Este Mês'),
  lastMonth('Mês Anterior'),
  thisYear('Este Ano'),
  all('Todo o Histórico');

  final String label;
  const ReportPeriod(this.label);
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FechamentoApiService _apiService = FechamentoApiService();

  bool _isLoading = true;
  String? _errorMessage;
  List<ServiceClosingDetail> _closingDetails = [];
  
  ReportPeriod _selectedPeriod = ReportPeriod.all;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final closings = await _apiService.fetchHistorico();
      
      List<ServiceClosingDetail> details = [];
      for (var summary in closings) {
        try {
          final detail = await _apiService.fetchClosingDetail(summary.id);
          details.add(detail);
        } catch (_) {
          // If individual detail fails, continue with others
        }
      }

      if (mounted) {
        setState(() {
          _closingDetails = details;
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
          }
          AuthApiService().logout().then((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            }
          });
        } else {
          setState(() {
            _errorMessage = 'Falha ao carregar dados dos relatórios: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    }
  }

  List<ServiceClosingDetail> get _filteredDetails {
    if (_closingDetails.isEmpty) return [];

    final now = DateTime.now();
    return _closingDetails.where((detail) {
      final date = _parseDate(detail.serviceDate);
      if (date == null) {
        return _selectedPeriod == ReportPeriod.all;
      }

      switch (_selectedPeriod) {
        case ReportPeriod.thisMonth:
          return date.year == now.year && date.month == now.month;
        case ReportPeriod.lastMonth:
          final lastMonthDate = DateTime(now.year, now.month - 1, 1);
          return date.year == lastMonthDate.year && date.month == lastMonthDate.month;
        case ReportPeriod.thisYear:
          return date.year == now.year;
        case ReportPeriod.all:
          return true;
      }
    }).toList();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'relatorios'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Relatórios Consolidados',
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
      content = _buildReportView(isDesktop);
    }

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSidebarDrawer(activeRoute: 'relatorios', permanent: true),
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
          const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar relatórios',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadReportData,
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

  Widget _buildReportView(bool isDesktop) {
    final filtered = _filteredDetails;

    double totalGeneral = 0;
    double totalDizimo = 0;
    double totalOferta = 0;
    double totalVoto = 0;
    double totalIdentified = 0;
    double totalAnonymous = 0;

    for (var detail in filtered) {
      totalGeneral += detail.registeredTotal;
      totalDizimo += detail.unidentifiedDizimoTotal;
      totalOferta += detail.unidentifiedOfertaTotal;
      totalVoto += detail.unidentifiedVotoTotal;

      for (var entry in detail.identifiedEntries) {
        final amount = entry.amount / 100.0;
        switch (entry.type) {
          case EnvelopeType.dizimo:
            totalDizimo += amount;
            break;
          case EnvelopeType.oferta:
            totalOferta += amount;
            break;
          case EnvelopeType.voto:
            totalVoto += amount;
            break;
        }
      }

      totalIdentified += detail.identifiedTotal;
      totalAnonymous += detail.unidentifiedTotal;
    }

    final int countCultos = filtered.length;
    final double averageCulto = countCultos > 0 ? totalGeneral / countCultos : 0;

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
              _buildPeriodSelector(),
              const SizedBox(height: 24),
              _buildMetricsGrid(totalGeneral, totalDizimo, totalOferta, totalVoto, averageCulto, countCultos),
              const SizedBox(height: 32),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCategoryBreakdownCard(totalGeneral, totalDizimo, totalOferta, totalVoto)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildOriginBreakdownCard(totalGeneral, totalIdentified, totalAnonymous)),
                  ],
                )
              else ...[
                _buildCategoryBreakdownCard(totalGeneral, totalDizimo, totalOferta, totalVoto),
                const SizedBox(height: 24),
                _buildOriginBreakdownCard(totalGeneral, totalIdentified, totalAnonymous),
              ],
              const SizedBox(height: 32),
              _buildExportCard(context, filtered, totalGeneral, totalDizimo, totalOferta, totalVoto),
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
          'RELATÓRIOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Consolidado Financeiro',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Visão geral das arrecadações por categoria e origem.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: ReportPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          return ChoiceChip(
            label: Text(
              period.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0xFF1E3A8A),
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            elevation: 0,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedPeriod = period);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricsGrid(double totalGeneral, double totalDizimo, double totalOferta, double totalVoto, double averageCulto, int countCultos) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _metricCard('Total Geral', 'CHF ${totalGeneral.toStringAsFixed(2)}', Icons.payments_outlined, const Color(0xFF1E3A8A)),
            _metricCard('Total Dízimos', 'CHF ${totalDizimo.toStringAsFixed(2)}', Icons.volunteer_activism_outlined, const Color(0xFF059669)),
            _metricCard('Total Ofertas', 'CHF ${totalOferta.toStringAsFixed(2)}', Icons.savings_outlined, const Color(0xFFD97706)),
            _metricCard('Total Votos', 'CHF ${totalVoto.toStringAsFixed(2)}', Icons.card_giftcard_outlined, const Color(0xFF7C3AED)),
            _metricCard('Média por Culto', 'CHF ${averageCulto.toStringAsFixed(2)}', Icons.bar_chart_rounded, const Color(0xFF2563EB)),
            _metricCard('Cultos Consolidados', '$countCultos', Icons.event_available_outlined, const Color(0xFF475569)),
          ],
        );
      },
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(double totalGeneral, double dizimo, double oferta, double voto) {
    final dizimoPct = totalGeneral > 0 ? (dizimo / totalGeneral) * 100 : 0.0;
    final ofertaPct = totalGeneral > 0 ? (oferta / totalGeneral) * 100 : 0.0;
    final votoPct = totalGeneral > 0 ? (voto / totalGeneral) * 100 : 0.0;

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
          const Text(
            'Distribuição por Categoria',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          _progressBarItem('Dízimo', dizimo, dizimoPct, const Color(0xFF059669)),
          const SizedBox(height: 12),
          _progressBarItem('Oferta', oferta, ofertaPct, const Color(0xFFD97706)),
          const SizedBox(height: 12),
          _progressBarItem('Voto', voto, votoPct, const Color(0xFF7C3AED)),
        ],
      ),
    );
  }

  Widget _buildOriginBreakdownCard(double totalGeneral, double identified, double anonymous) {
    final identifiedPct = totalGeneral > 0 ? (identified / totalGeneral) * 100 : 0.0;
    final anonymousPct = totalGeneral > 0 ? (anonymous / totalGeneral) * 100 : 0.0;

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
          const Text(
            'Identificado vs. Anônimo',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          _progressBarItem('Identificado (Envelopes)', identified, identifiedPct, const Color(0xFF1E3A8A)),
          const SizedBox(height: 12),
          _progressBarItem('Anônimo (Bandeja / Coleta)', anonymous, anonymousPct, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _progressBarItem(String title, double amount, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text(
              'CHF ${amount.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'monospace'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildExportCard(BuildContext context, List<ServiceClosingDetail> details, double totalGeral, double dizimo, double oferta, double voto) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined, size: 32, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exportar Relatório Consolidado',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Gere um documento de resumo do período selecionado para arquivamento contábil.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Relatório pronto para impressão/exportação.')),
              );
            },
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Exportar / Imprimir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
