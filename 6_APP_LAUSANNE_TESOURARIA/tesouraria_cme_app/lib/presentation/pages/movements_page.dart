import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_api_service.dart';
import '../../services/movements_api_service.dart';
import '../../domain/movement_models.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'login_page.dart';
import 'closing_detail_page.dart';
import 'expenses_page.dart';

class MovementsPage extends StatefulWidget {
  const MovementsPage({super.key});

  @override
  State<MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<MovementsPage> {
  final MovementsApiService _apiService = MovementsApiService();

  bool _isLoading = true;
  String? _errorMessage;
  MovementResponse? _response;

  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.fetchMovements(_selectedYear, _selectedMonth);
      if (mounted) {
        setState(() {
          _response = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('UNAUTHORIZED')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sessao expirada. Faca login novamente.')),
          );
          await AuthApiService().logout();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Falha ao carregar movimentos.';
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Converts "YYYY-MM-DD" -> "DD/MM/AAAA".
  String _formatDate(String raw) {
    try {
      final parts = raw.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {}
    return raw;
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
              backgroundColor: AppTheme.institutionalBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Movimentos Financeiros',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
      body: _buildBody(context, isDesktop),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    Widget content;

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator(color: AppTheme.institutionalBlue));
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: content,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMovements,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.institutionalBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsView(bool isDesktop) {
    final items = _response?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildHeader(isDesktop),
              _buildMonthSelector(),
            ],
          )
        else ...[
          _buildHeader(isDesktop),
          const SizedBox(height: 16),
          _buildMonthSelector(),
        ],
        const SizedBox(height: 20),
        _buildSummaryCards(isDesktop),
        const SizedBox(height: 24),
        _buildMovementsTable(items, isDesktop),
      ],
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movimentos Financeiros',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    Widget styledDropdown({required Widget child}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: child,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        styledDropdown(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedMonth,
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(months[i], style: const TextStyle(fontSize: 13)),
              )),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _loadMovements();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        styledDropdown(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              items: [DateTime.now().year, DateTime.now().year - 1]
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text(y.toString(), style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _loadMovements();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isDesktop) {
    final incomes = _response?.totalIncomes ?? 0.0;
    final outcomes = _response?.totalOutcomes ?? 0.0;
    final balance = _response?.balance ?? 0.0;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Text('Entradas: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            Text('CHF ${incomes.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            const SizedBox(width: 16),
            const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
            const SizedBox(width: 16),
            const Text('Saídas: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            Text('CHF ${outcomes.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
            const SizedBox(width: 16),
            const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
            const SizedBox(width: 16),
            const Text('Saldo: ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            Text('CHF ${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balance < 0 ? const Color(0xFFDC2626) : const Color(0xFF059669))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Entradas', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('CHF ${incomes.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saídas', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('CHF ${outcomes.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('CHF ${balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balance < 0 ? const Color(0xFFDC2626) : const Color(0xFF059669))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsTable(List<MovementItem> items, bool isDesktop) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    'DATA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'DESCRICAO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'VALOR',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Nenhum movimento neste mes.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final item = items[index];
                final isIncome = item.type == 'INCOME';
                final displayDate = _formatDate(item.date);
                final numericId = int.tryParse(item.id);

                return InkWell(
                  onTap: numericId == null
                      ? null
                      : () {
                          if (isIncome) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ClosingDetailPage(closingId: numericId),
                              ),
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ExpensesPage(),
                              ),
                            );
                          }
                        },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            displayDate,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                item.category,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${isIncome ? '+' : '-'} CHF ${item.value.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isIncome
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
