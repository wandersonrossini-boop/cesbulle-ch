import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/fechamento_api_service.dart';
import '../../services/auth_api_service.dart';
import '../../services/expense_api_service.dart';
import '../../services/dashboard_api_service.dart';
import '../widgets/audit_logs_dialog.dart';
import 'login_page.dart';
import 'placeholder_page.dart';
import 'closing_detail_page.dart';
import 'wizard_page.dart';
import 'members_page.dart';
import 'reports_page.dart';
import 'expenses_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/history_bloc.dart';
import '../widgets/app_sidebar_drawer.dart';
import '../widgets/dashboard_summary_cards.dart';
import '../../domain/service_closing_history_models.dart';
import '../../core/monetary_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoryBloc(FechamentoApiService())..add(LoadHistoryEvent()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  String _userName = 'Tesoureiro';
  String? _userRole;
  double _totalSaidas = 0.0;
  final DashboardApiService _dashboardApiService = DashboardApiService();
  DashboardSummaryModel? _summary;
  bool _loadingSummary = true;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _loadUserNameAndRole();
    _loadTotalSaidas();
    _loadDashboardSummary();
  }

  Future<void> _loadDashboardSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary = await _dashboardApiService.fetchDashboardSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _loadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = e.toString().replaceFirst('Exception: ', '');
          _loadingSummary = false;
        });
      }
    }
  }

  Future<void> _loadTotalSaidas() async {
    try {
      final total = await ExpenseApiService().fetchTotalApprovedExpenses();
      if (mounted) {
        setState(() {
          _totalSaidas = total;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadUserNameAndRole() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null) {
      final savedUser = prefs.getString('username');
      final savedRole = prefs.getString('user_role');
      if (mounted) {
        setState(() {
          if (savedUser != null && savedUser.isNotEmpty) {
            _userName = savedUser.substring(0, 1).toUpperCase() + savedUser.substring(1);
          }
          _userRole = savedRole;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'dashboard'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Visão geral',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
          if (state is HistoryError && state.isUnauthorized) {
            AuthApiService().logout().then((_) {
              if (context.mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            });
          } else if (state is HistoryError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is HistoryLoading || state is HistoryInitial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryLoaded) {
            final content = _buildMainContent(context, state, isDesktop);

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSidebarDrawer(activeRoute: 'dashboard', permanent: true),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: content,
            );
          }
          return const Center(child: Text("Erro ao carregar histórico."));
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, HistoryLoaded state, bool isDesktop) {
    final historico = state.history;
    double totalEntradas = historico.fold(0, (sum, item) => sum + item.physicalTotal);
    String dateStr = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now()).toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Greeting & Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $_userName!',
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (_loadingSummary)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
          ],
        ),
        const SizedBox(height: 24),

        // Warning Banner for Pending Expenses
        if (!_loadingSummary && _summary != null && _summary!.pendingExpensesCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você tem ${_summary!.pendingExpensesCount} despesa(s) aguardando aprovação (Total: CHF ${_summary!.pendingExpensesTotal.toStringAsFixed(2)}).',
                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => const ExpensesPage(),
                    ));
                  },
                  child: const Text(
                    'Revisar Saídas',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Layout Principal
        if (isDesktop)
          _buildDesktopLayout(context, historico, totalEntradas)
        else
          _buildMobileLayout(context, historico, totalEntradas),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, List<ServiceClosingSummary> history, double totalEntradas) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Hero Card & Quick Actions)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroCard(totalEntradas),
              const SizedBox(height: 24),
              _buildQuickActionsGrid(context),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column (Recent Activities)
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMovimentosSection(context, history, isDesktop: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<ServiceClosingSummary> history, double totalEntradas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroCard(totalEntradas),
        const SizedBox(height: 24),
        _buildQuickActionsGrid(context),
        const SizedBox(height: 32),
        _buildMovimentosSection(context, history, isDesktop: false),
      ],
    );
  }

  Widget _buildHeroCard(double totalEntradas) {
    final displayMonth = _summary?.periodLabel ?? '--/----';
    final currentInputs = _summary?.currentMonthInputs ?? totalEntradas;
    final isLocked = _summary?.periodLocked ?? false;
    final isSurplus = currentInputs >= _totalSaidas;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMPETÊNCIA $displayMonth',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLocked ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isLocked ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7)),
                ),
                child: Text(
                  isLocked ? 'FECHADO' : 'ABERTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Entradas do Mês',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'CHF ${currentInputs.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final List<Widget> actions = [
      _buildActionCard(
        context: context,
        icon: Icons.add_circle_outline_rounded,
        title: 'Contagem do culto',
        subtitle: 'Submeter ata de culto',
        color: const Color(0xFF1E3A8A),
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WizardPage()),
          );
        },
      ),
      _buildActionCard(
        context: context,
        icon: Icons.people_outline_rounded,
        title: 'Cadastro e declarações',
        subtitle: 'Gerenciar dizimistas',
        color: const Color(0xFF0D9488),
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MembersPage()),
          );
        },
      ),
      _buildActionCard(
        context: context,
        icon: Icons.bar_chart_rounded,
        title: 'Ver Relatório',
        subtitle: 'Balancete do mês',
        color: const Color(0xFFD97706),
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ReportsPage()),
          );
        },
      ),
    ];

    if (_userRole == 'ADMIN') {
      actions.add(
        _buildActionCard(
          context: context,
          icon: Icons.history_toggle_off_rounded,
          title: 'Auditoria',
          subtitle: 'Trilha de ações',
          color: const Color(0xFF475569),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const AuditLogsDialog(),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AÇÕES RÁPIDAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: actions.map((card) {
                return SizedBox(
                  width: cardWidth > 150 ? cardWidth : double.infinity,
                  child: card,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimentosSection(BuildContext context, List<ServiceClosingSummary> history, {required bool isDesktop}) {
    final recentItems = history.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isDesktop ? 'ÚLTIMOS MOVIMENTOS' : 'ATIVIDADE RECENTE',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => const PlaceholderPage(
                    title: 'Movimentos',
                    route: 'movimentos',
                    icon: Icons.receipt_long_rounded,
                    description: 'Visualize entradas e saídas\nde cada culto.',
                  ),
                ));
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isDesktop ? 'Ver todos' : 'Ver movimentos',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentItems.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'Nenhum movimento registrado.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final item = recentItems[index];
                
                // Formata data curta "09 ago"
                String shortDate = item.serviceDate;
                try {
                  final parts = item.serviceDate.split('/');
                  if (parts.length == 3) {
                    final day = parts[0];
                    final month = int.tryParse(parts[1]) ?? 1;
                    const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
                    shortDate = "$day ${months[month - 1]}".toUpperCase();
                  }
                } catch (_) {}

                return InkWell(
                  onTap: () async {
                    final shouldReload = await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ClosingDetailPage(closingId: item.id),
                    ));
                    if (shouldReload == true && context.mounted) {
                      context.read<HistoryBloc>().add(LoadHistoryEvent());
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Short date block
                        SizedBox(
                          width: 54,
                          child: Text(
                            shortDate,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Details column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fechamento do culto',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.mainTreasurer,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Monetary amount
                        Text(
                          "+ CHF ${BigDecimalConverter.format(item.physicalTotal)}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E7E34),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  List<MonthlyFinancialData> _getMonthlyData(List<ServiceClosingSummary> history) {
    final Map<String, double> monthlyEntries = {};
    
    for (var item in history) {
      try {
        final cleanDate = item.serviceDate.trim();
        final parts = cleanDate.split('/');
        if (parts.length == 3) {
          int month = int.tryParse(parts[1]) ?? 1;
          final monthAbbrev = _getMonthAbbrev(month);
          monthlyEntries[monthAbbrev] = (monthlyEntries[monthAbbrev] ?? 0.0) + item.physicalTotal;
        }
      } catch (_) {}
    }
    
    final List<String> last6Months = [];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final mDate = DateTime(now.year, now.month - i, 1);
      last6Months.add(_getMonthAbbrev(mDate.month));
    }
    
    return last6Months.map((m) {
      double entries = monthlyEntries[m] ?? 0.0;
      return MonthlyFinancialData(m, entries, 0.0, entries);
    }).toList();
  }

  String _getMonthAbbrev(int month) {
    if (month >= 1 && month <= 12) {
      // Return local Portuguese-style abbrevs
      const ptMonths = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
      return ptMonths[month - 1];
    }
    return '';
  }
}

class MonthlyFinancialData {
  final String monthAbbrev;
  final double entries;
  final double expenses;
  final double balance;

  MonthlyFinancialData(this.monthAbbrev, this.entries, this.expenses, this.balance);
}

class LineChartPainter extends CustomPainter {
  final List<MonthlyFinancialData> data;
  LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLineEntries = Paint()
      ..color = const Color(0xFF1E7E34) // green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintPointEntries = Paint()
      ..color = const Color(0xFF1E7E34)
      ..style = PaintingStyle.fill;

    final paintLineSaldo = Paint()
      ..color = const Color(0xFF1E3A8A) // deep blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintPointSaldo = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.fill;

    final paintGrid = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    // Find max value to scale chart appropriately
    double maxVal = 1000.0;
    for (var d in data) {
      if (d.entries > maxVal) maxVal = d.entries;
    }
    maxVal = ((maxVal / 1000).ceil() * 1000).toDouble();

    // Draw horizontal grid lines and scale text labels
    final double stepY = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      double y = stepY * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
      
      double val = maxVal - (maxVal / 4 * i);
      final textSpan = TextSpan(
        text: val >= 1000 ? "${(val / 1000).toStringAsFixed(0)}k" : val.toStringAsFixed(0),
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontFamily: 'monospace'),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(-24, y - 6));
    }

    // Draw month names below the chart
    final double stepX = size.width / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      double x = stepX * i;
      final textSpan = TextSpan(
        text: data[i].monthAbbrev,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - 10, size.height + 8));
    }

    // Plot lines
    final Path pathEntries = Path();
    final Path pathSaldo = Path();

    for (int i = 0; i < data.length; i++) {
      double x = stepX * i;
      double yEntries = size.height - (data[i].entries / maxVal * size.height);
      double ySaldo = size.height - (data[i].balance / maxVal * size.height);

      if (i == 0) {
        pathEntries.moveTo(x, yEntries);
        pathSaldo.moveTo(x, ySaldo);
      } else {
        pathEntries.lineTo(x, yEntries);
        pathSaldo.lineTo(x, ySaldo);
      }
    }

    canvas.drawPath(pathEntries, paintLineEntries);
    canvas.drawPath(pathSaldo, paintLineSaldo);

    // Plot data points
    for (int i = 0; i < data.length; i++) {
      double x = stepX * i;
      double yEntries = size.height - (data[i].entries / maxVal * size.height);
      double ySaldo = size.height - (data[i].balance / maxVal * size.height);

      canvas.drawCircle(Offset(x, yEntries), 3.5, paintPointEntries);
      canvas.drawCircle(Offset(x, ySaldo), 3.5, paintPointSaldo);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
