import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_api_service.dart';
import '../../services/financial_report_api_service.dart';
import '../../services/user_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';
import '../widgets/audit_logs_dialog.dart';
import 'login_page.dart';
import '../../utils/file_download_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FinancialReportApiService _apiService = FinancialReportApiService();

  bool _isLoading = true;
  String? _errorMessage;
  MonthlyReportModel? _report;
  String _periodStatus = 'OPEN';
  AppUser? _currentUser;
  bool _isLockingOrUnlocking = false;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isExporting = false;
  bool _isCreatingSheets = false;

  final List<int> _years = List.generate(5, (index) => DateTime.now().year - index);
  final List<Map<String, dynamic>> _months = [
    {'value': 1, 'label': 'Janeiro'},
    {'value': 2, 'label': 'Fevereiro'},
    {'value': 3, 'label': 'Março'},
    {'value': 4, 'label': 'Abril'},
    {'value': 5, 'label': 'Maio'},
    {'value': 6, 'label': 'Junho'},
    {'value': 7, 'label': 'Julho'},
    {'value': 8, 'label': 'Agosto'},
    {'value': 9, 'label': 'Setembro'},
    {'value': 10, 'label': 'Outubro'},
    {'value': 11, 'label': 'Novembro'},
    {'value': 12, 'label': 'Dezembro'},
  ];

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
      final report = await _apiService.fetchMonthlyReport(_selectedMonth, _selectedYear);
      final status = await _apiService.fetchPeriodStatus(_selectedMonth, _selectedYear);
      if (_currentUser == null) {
        _currentUser = await UserApiService().getMyProfile();
      }
      if (mounted) {
        setState(() {
          _report = report;
          _periodStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('UNAUTHORIZED')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sessão expirada. Faça login novamente.'),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          AuthApiService().logout().then((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            }
          });
        } else {
          setState(() {
            _errorMessage = 'Falha ao carregar relatório: ${e.toString().replaceFirst('Exception: ', '')}';
            _isLoading = false;
          });
        }
      }
    }
  }

  bool _isExportingPdf = false;

  Future<void> _exportCsv({bool openSheets = false}) async {
    setState(() {
      _isExporting = true;
    });
    try {
      final csvBytes = await _apiService.downloadMonthlyReportCsv(_selectedMonth, _selectedYear);
      final monthString = _selectedMonth.toString().padLeft(2, '0');
      downloadFile(csvBytes, 'relatorio_${monthString}_$_selectedYear.csv');
      
      if (openSheets) {
        final prefs = await SharedPreferences.getInstance();
        final sheetsUrl = prefs.getString('google_sheets_url') ?? '';
        if (sheetsUrl.isNotEmpty && sheetsUrl.startsWith('http')) {
          openUrl(sheetsUrl);
        } else {
          openUrl('https://docs.google.com/spreadsheets');
        }
      }

      if (mounted) {
        if (openSheets) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Arquivo baixado e pronto para importação'),
              content: const Text(
                'O arquivo CSV foi baixado no seu navegador e o Google Planilhas foi aberto em uma nova aba.\n\n'
                'Como visualizar os dados no Google Planilhas:\n'
                '1. Na página do Google Planilhas, crie uma planilha em branco ("Em branco").\n'
                '2. Clique no menu superior: "Arquivo" > "Importar".\n'
                '3. Vá para a aba "Fazer upload" e selecione o arquivo CSV baixado.\n'
                '4. Mantenha as opções padrões e clique em "Importar dados".',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Relatório CSV exportado com sucesso!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _openGoogleSheetsDirectly() async {
    setState(() {
      _isCreatingSheets = true;
    });
    try {
      final url = await _apiService.createGoogleSheetsReport(_selectedMonth, _selectedYear);
      if (url.isNotEmpty) {
        openUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Planilha criada e aberta no Google Planilhas!')),
          );
        }
      } else {
        throw Exception('A URL da planilha retornou vazia.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir planilha: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSheets = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    setState(() {
      _isExportingPdf = true;
    });
    try {
      final pdfBytes = await _apiService.downloadMonthlyReportPdf(_selectedMonth, _selectedYear);
      final monthString = _selectedMonth.toString().padLeft(2, '0');
      downloadFile(pdfBytes, 'relatorio_${monthString}_$_selectedYear.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Relatório PDF exportado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    } finally {
      setState(() {
        _isExportingPdf = false;
      });
    }
  }

  Future<void> _togglePeriodLock() async {
    final isLocked = _periodStatus == 'LOCKED';
    final actionWord = isLocked ? 'reabrir' : 'trancar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isLocked ? "Reabrir" : "Trancar"} Período Contábil'),
        content: Text('Tem certeza que deseja $actionWord a competência contábil de ${_months.firstWhere((m) => m['value'] == _selectedMonth)['label']} de $_selectedYear?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: isLocked ? AppTheme.primaryGreen : AppTheme.excludeRed),
            child: Text(isLocked ? 'REABRIR' : 'TRANCAR', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLockingOrUnlocking = true;
      });
      try {
        if (isLocked) {
          await _apiService.unlockPeriod(_selectedMonth, _selectedYear);
        } else {
          await _apiService.lockPeriod(_selectedMonth, _selectedYear);
        }
        await _loadReportData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Competência contábil ${isLocked ? "reaberta" : "trancada"} com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.excludeRed),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLockingOrUnlocking = false;
          });
        }
      }
    }
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
                'Relatórios Contábeis',
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
    final report = _report;
    if (report == null) return const Center(child: Text("Sem dados disponíveis."));

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 24),
              _buildFiltersCard(isDesktop),
              const SizedBox(height: 24),
              _buildKpis(report, isDesktop),
              const SizedBox(height: 24),
              _buildTables(report, isDesktop),
              const SizedBox(height: 24),
              _buildExportSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    final isLocked = _periodStatus == 'LOCKED';
    final statusColor = isLocked ? const Color(0xFFDC2626) : AppTheme.primaryGreen;
    final statusText = isLocked ? 'TRAVADO PARA AUDITORIA' : 'COMPETÊNCIA ABERTA';
    final statusIcon = isLocked ? Icons.lock_rounded : Icons.lock_open_rounded;

    Widget titleAndStatus = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Relatório Financeiro Oficial',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
        ),
      ],
    );

    Widget description = const Text(
      'Demonstrativo mensal consolidado de arrecadações e despesas liquidadas.',
      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleAndStatus,
                const SizedBox(height: 4),
                description,
              ],
            ),
          ),
          if (_currentUser?.role == 'ADMIN')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AuditLogsDialog(),
                    );
                  },
                  icon: const Icon(Icons.history_toggle_off_rounded, size: 16, color: Color(0xFF1E3A8A)),
                  label: const Text('TRILHA DE AUDITORIA', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLockingOrUnlocking ? null : _togglePeriodLock,
                  icon: _isLockingOrUnlocking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 16, color: Colors.white),
                  label: Text(isLocked ? 'REABRIR COMPETÊNCIA' : 'TRANCAR MES/PERÍODO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocked ? AppTheme.primaryGreen : const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleAndStatus,
          const SizedBox(height: 8),
          description,
          if (_currentUser?.role == 'ADMIN') ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AuditLogsDialog(),
                    );
                  },
                  icon: const Icon(Icons.history_toggle_off_rounded, size: 16, color: Color(0xFF1E3A8A)),
                  label: const Text('TRILHA DE AUDITORIA', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isLockingOrUnlocking ? null : _togglePeriodLock,
                  icon: _isLockingOrUnlocking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 16, color: Colors.white),
                  label: Text(isLocked ? 'REABRIR COMPETÊNCIA' : 'TRANCAR MES/PERÍODO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocked ? AppTheme.primaryGreen : const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }
  }

  Widget _buildFiltersCard(bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Filtros de Período:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: const InputDecoration(labelText: 'Mês', border: OutlineInputBorder()),
                items: _months.map((m) {
                  return DropdownMenuItem<int>(
                    value: m['value'] as int,
                    child: Text(m['label'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMonth = val);
                    _loadReportData();
                  }
                },
              ),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(labelText: 'Ano', border: OutlineInputBorder()),
                items: _years.map((y) {
                  return DropdownMenuItem<int>(
                    value: y,
                    child: Text('$y'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedYear = val);
                    _loadReportData();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpis(MonthlyReportModel report, bool isDesktop) {
    final balanceColor = report.netBalance >= 0 ? AppTheme.primaryGreen : AppTheme.excludeRed;
    
    if (isDesktop) {
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: [
          _buildKpiCard("TOTAL ENTRADAS", "CHF ${_formatCHF(report.totalIncomes)}", const Color(0xFF1E3A8A), Icons.arrow_upward_rounded),
          _buildKpiCard("SAÍDAS PAGAS", "CHF ${_formatCHF(report.totalExpenses)}", AppTheme.excludeRed, Icons.arrow_downward_rounded),
          _buildKpiCard("DESPESAS APROVADAS A PAGAR", "CHF ${_formatCHF(report.totalCommitted)}", const Color(0xFFD97706), Icons.hourglass_empty_rounded),
          _buildKpiCard("SALDO LÍQUIDO REALIZADO", "CHF ${_formatCHF(report.netBalance)}", balanceColor, Icons.account_balance_rounded),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMobileKpiRow("Saldo Líquido Realizado", "CHF ${_formatCHF(report.netBalance)}", amountColor: balanceColor, isBold: true),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            _buildMobileKpiRow("Total Entradas", "CHF ${_formatCHF(report.totalIncomes)}", amountColor: AppTheme.institutionalBlue),
            const SizedBox(height: 10),
            _buildMobileKpiRow("Saídas Pagas", "CHF ${_formatCHF(report.totalExpenses)}", amountColor: AppTheme.excludeRed),
            const SizedBox(height: 10),
            _buildMobileKpiRow("Despesas Aprovadas a Pagar", "CHF ${_formatCHF(report.totalCommitted)}", amountColor: const Color(0xFFD97706)),
          ],
        ),
      );
    }
  }

  Widget _buildMobileKpiRow(String label, String value, {required Color amountColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF475569),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTables(MonthlyReportModel report, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildCategoryTable("Entradas por Categoria", report.incomesByCategory, true)),
          const SizedBox(width: 24),
          Expanded(child: _buildCategoryTable("Saídas Pagas por Categoria", report.expensesByCategory, false)),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoryTable("Entradas por Categoria", report.incomesByCategory, true),
          const SizedBox(height: 24),
          _buildCategoryTable("Saídas Pagas por Categoria", report.expensesByCategory, false),
        ],
      );
    }
  }

  Widget _buildCategoryTable(String title, List<CategorySummaryModel> list, bool isInflow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text("Sem lançamentos no período.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.2),
              },
              border: const TableBorder(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                horizontalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
              children: [
                _buildTableHeader(['Categoria', 'Total']),
                ...list.map((item) {
                  return _buildTableRow(item.category, 'CHF ${_formatCHF(item.total)}');
                }),
              ],
            ),
        ],
      ),
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

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'monospace')),
        ),
      ],
    );
  }

  Widget _buildExportSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    final btnPdf = ElevatedButton.icon(
      onPressed: _isExportingPdf ? null : _exportPdf,
      icon: _isExportingPdf
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
      label: const Text('Exportar PDF Oficial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        minimumSize: isMobile ? const Size(double.infinity, 48) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final btnCsv = ElevatedButton.icon(
      onPressed: _isExporting ? null : () => _exportCsv(openSheets: false),
      icon: _isExporting
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
      label: const Text('Baixar CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        minimumSize: isMobile ? const Size(double.infinity, 48) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final btnSheets = ElevatedButton.icon(
      onPressed: (_isExporting || _isCreatingSheets) ? null : _openGoogleSheetsDirectly,
      icon: _isCreatingSheets
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.table_chart_rounded, color: Colors.white, size: 20),
      label: const Text('Abrir no Google Planilhas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF15803D), // Spreadsheet Green
        minimumSize: isMobile ? const Size(double.infinity, 48) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final List<Widget> buttonsList = isMobile
        ? [
            btnPdf,
            const SizedBox(height: 10),
            btnCsv,
            const SizedBox(height: 10),
            btnSheets,
          ]
        : [
            btnPdf,
            const SizedBox(width: 12),
            btnCsv,
            const SizedBox(width: 12),
            btnSheets,
          ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exportar Balanço Geral',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gere uma exportação oficial em formato CSV ou PDF com todos os detalhes do período para conciliação contábil.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ...buttonsList,
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exportar Balanço Geral',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gere uma exportação oficial em formato CSV ou PDF com todos os detalhes do período para conciliação contábil.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Row(mainAxisSize: MainAxisSize.min, children: buttonsList),
                ],
              ),
      ),
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
