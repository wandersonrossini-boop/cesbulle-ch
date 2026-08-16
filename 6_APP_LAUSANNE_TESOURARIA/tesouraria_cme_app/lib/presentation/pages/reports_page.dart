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
        return false;
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
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 16),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 24),
              _buildMainSummary(totalGeneral, countCultos, averageCulto),
              const SizedBox(height: 32),
              _buildCompositionTable(totalGeneral, totalDizimo, totalOferta, totalVoto),
              const SizedBox(height: 32),
              _buildOriginTable(totalGeneral, totalIdentified, totalAnonymous),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 24),
              _buildArchiveSection(context),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: ReportPeriod.values.asMap().entries.map((entry) {
        final index = entry.key;
        final period = entry.value;
        final isSelected = _selectedPeriod == period;

        final textWidget = InkWell(
          onTap: () {
            setState(() => _selectedPeriod = period);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              period.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        );

        if (index < ReportPeriod.values.length - 1) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              textWidget,
              const SizedBox(width: 8),
              const Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
            ],
          );
        } else {
          return textWidget;
        }
      }).toList(),
    );
  }

  Widget _buildMainSummary(double totalGeneral, int countCultos, double averageCulto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOTAL CONSOLIDADO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'CHF ${_formatCHF(totalGeneral)}',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$countCultos ${countCultos == 1 ? 'culto consolidado' : 'cultos consolidados'} · Média de CHF ${_formatCHF(averageCulto)} por culto',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildCompositionTable(double totalGeneral, double dizimo, double oferta, double voto) {
    final dizimoPct = totalGeneral > 0 ? (dizimo / totalGeneral) * 100 : null;
    final ofertaPct = totalGeneral > 0 ? (oferta / totalGeneral) * 100 : null;
    final votoPct = totalGeneral > 0 ? (voto / totalGeneral) * 100 : null;

    String pctFormat(double? pct) => pct != null ? '${pct.toStringAsFixed(1)}%' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Composição financeira',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          border: const TableBorder(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            horizontalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
          children: [
            _buildTableHeader(['Categoria', 'Valor', '% do total']),
            _buildTableRow('Dízimos', 'CHF ${_formatCHF(dizimo)}', pctFormat(dizimoPct)),
            _buildTableRow('Ofertas', 'CHF ${_formatCHF(oferta)}', pctFormat(ofertaPct)),
            _buildTableRow('Votos', 'CHF ${_formatCHF(voto)}', pctFormat(votoPct)),
            _buildTableRow('Total', 'CHF ${_formatCHF(totalGeneral)}', totalGeneral > 0 ? '100.0%' : '—', isTotal: true),
          ],
        ),
      ],
    );
  }

  Widget _buildOriginTable(double totalGeneral, double identified, double anonymous) {
    final identifiedPct = totalGeneral > 0 ? (identified / totalGeneral) * 100 : null;
    final anonymousPct = totalGeneral > 0 ? (anonymous / totalGeneral) * 100 : null;

    String pctFormat(double? pct) => pct != null ? '${pct.toStringAsFixed(1)}%' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Origem dos valores',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          border: const TableBorder(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            horizontalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
          children: [
            _buildTableHeader(['Origem', 'Valor', '% do total']),
            _buildTableRow('Identificado (Envelopes)', 'CHF ${_formatCHF(identified)}', pctFormat(identifiedPct)),
            _buildTableRow('Anônimo (Bandeja / Coleta)', 'CHF ${_formatCHF(anonymous)}', pctFormat(anonymousPct)),
            _buildTableRow('Total', 'CHF ${_formatCHF(totalGeneral)}', totalGeneral > 0 ? '100.0%' : '—', isTotal: true),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableHeader(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      children: headers.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            text,
            textAlign: index == 0 ? TextAlign.left : TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        );
      }).toList(),
    );
  }

  TableRow _buildTableRow(String label, String value, String percentage, {bool isTotal = false}) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: const Color(0xFF0F172A),
    );
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: const Color(0xFF0F172A),
      fontFamily: 'monospace',
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(label, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(value, textAlign: TextAlign.right, style: valueStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(percentage, textAlign: TextAlign.right, style: valueStyle),
        ),
      ],
    );
  }

  Widget _buildArchiveSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Relatório para arquivo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 2),
              Text(
                'Gere um documento de resumo do período selecionado para arquivamento contábil.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Relatório pronto para impressão/exportação.')),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Exportar / Imprimir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  String _formatCHF(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    final String parts = absValue.toStringAsFixed(2);
    final List<String> split = parts.split('.');
    final String whole = split[0];
    final String decimal = split[1];

    final buffer = StringBuffer();
    final int len = whole.length;
    for (int i = 0; i < len; i++) {
      buffer.write(whole[i]);
      if ((len - 1 - i) % 3 == 0 && i != len - 1) {
        buffer.write("'");
      }
    }
    return "${isNegative ? '-' : ''}${buffer.toString()}.$decimal";
  }
}
