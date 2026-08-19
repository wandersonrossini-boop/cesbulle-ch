import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/expense_api_service.dart';
import '../../services/auth_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'login_page.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final ExpenseApiService _apiService = ExpenseApiService();
  
  bool _isLoading = true;
  String? _errorMessage;
  List<ExpenseModel> _expenses = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      _isAdmin = username == 'pastor';

      final data = await _apiService.fetchExpenses();
      if (mounted) {
        setState(() {
          _expenses = data;
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
            _errorMessage = 'Falha ao carregar despesas: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showAddExpenseDialog() {
    final descController = TextEditingController();
    final supplierController = TextEditingController();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final dateController = TextEditingController();
    
    // Set default date as today
    final now = DateTime.now();
    dateController.text = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    
    String category = 'Utilidades';
    String paymentMethod = 'Caixa Físico';

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Registrar Nova Despesa',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF6B7280), size: 20),
                            onPressed: () => Navigator.pop(dlgContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                          labelText: 'Data da despesa (DD/MM/AAAA)',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição da despesa',
                          hintText: 'Ex: Conta de água, compra de material...',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: supplierController,
                        decoration: const InputDecoration(
                          labelText: 'Fornecedor / Beneficiário',
                          hintText: 'Ex: SIL, Régie...',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Aluguel & Local', child: Text('Aluguel & Local')),
                          DropdownMenuItem(value: 'Utilidades', child: Text('Utilidades (Água/Luz/Net)')),
                          DropdownMenuItem(value: 'Manutenção & Equipamento', child: Text('Manutenção & Equipamentos')),
                          DropdownMenuItem(value: 'Eventos & Ministério', child: Text('Eventos & Ministério')),
                          DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Forma de Pagamento',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Caixa Físico', child: Text('Caixa Físico')),
                          DropdownMenuItem(value: 'Transferência Bancária', child: Text('Transferência Bancária')),
                          DropdownMenuItem(value: 'Cartão de Débito', child: Text('Cartão de Débito')),
                          DropdownMenuItem(value: 'Dinheiro Pessoal (Reembolso)', child: Text('Dinheiro Pessoal (Reembolso)')),
                          DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => paymentMethod = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Referência / Comprovante (Opcional)',
                          hintText: 'Ex: Fatura 12345, Recibo...',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Valor (CHF)',
                          prefixText: 'CHF ',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dlgContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF475569))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final desc = descController.text.trim();
                                final supplier = supplierController.text.trim();
                                final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                                final dateVal = dateController.text.trim();
                                final ref = refController.text.trim();

                                if (desc.isNotEmpty && amount > 0) {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    Navigator.pop(dlgContext);
                                    setState(() => _isLoading = true);
                                    await _apiService.createExpense(
                                      description: desc,
                                      supplier: supplier.isEmpty ? 'N/I' : supplier,
                                      category: category,
                                      amount: amount,
                                      localDateStr: dateVal,
                                      paymentMethod: paymentMethod,
                                      receiptReference: ref,
                                    );
                                    _loadInitialData();
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Erro ao salvar despesa: $e'), backgroundColor: Colors.red),
                                    );
                                    _loadInitialData();
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('SALVAR DESPESA'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReversalDialog(ExpenseModel expense) {
    final justificationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Justificativa de Estorno', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lançamentos contábeis não podem ser excluídos fisicamente. Justifique o estorno desta despesa:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: justificationController,
                decoration: const InputDecoration(
                  labelText: 'Motivo do estorno',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final justification = justificationController.text.trim();
                if (justification.isNotEmpty) {
                  try {
                    Navigator.pop(dlgContext);
                    setState(() => _isLoading = true);
                    final idInt = int.parse(expense.id);
                    await _apiService.reverseExpense(idInt, justification);
                    _loadInitialData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao estornar despesa: $e'), backgroundColor: Colors.red),
                      );
                      _loadInitialData();
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('CONFIRMAR ESTORNO'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleApprove(ExpenseModel expense) async {
    try {
      setState(() => _isLoading = true);
      await _apiService.approveExpense(int.parse(expense.id));
      _loadInitialData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar despesa: $e'), backgroundColor: Colors.red),
        );
        _loadInitialData();
      }
    }
  }

  void _showRejectionDialog(ExpenseModel expense) {
    final justificationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Justificativa de Rejeição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informe o motivo da rejeição desta despesa:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: justificationController,
                decoration: const InputDecoration(
                  labelText: 'Motivo da rejeição',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final justification = justificationController.text.trim();
                if (justification.isNotEmpty) {
                  try {
                    Navigator.pop(dlgContext);
                    setState(() => _isLoading = true);
                    final idInt = int.parse(expense.id);
                    await _apiService.rejectExpense(idInt, justification);
                    _loadInitialData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao rejeitar despesa: $e'), backgroundColor: Colors.red),
                      );
                      _loadInitialData();
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('CONFIRMAR REJEIÇÃO'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    // Only approved expenses sum up for consolidated outflow reports
    final totalApproved = _expenses
        .where((item) => item.status == 'APPROVED')
        .fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'despesas'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Gestão de Despesas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const AppSidebarDrawer(activeRoute: 'despesas', permanent: true),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : SingleChildScrollView(
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
                                _buildSummaryCard(totalApproved, _expenses.length),
                                const SizedBox(height: 24),
                                _buildExpensesTable(isDesktop),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Erro desconhecido',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            child: const Text('Recarregar'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Despesas da Congregação',
              style: TextStyle(
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Acompanhamento e auditoria contábil de despesas da igreja.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _showAddExpenseDialog,
          icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F172A)),
          label: const Text('Nova Despesa', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(double total, int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOTAL DESPESAS APROVADAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'CHF ${_formatCHF(total)}',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total acumulado e validado em despesas ($totalCount lançamentos cadastrados)',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildExpensesTable(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Detalhamento de Saídas',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        if (_expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text('Nenhuma despesa registrada.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ),
          )
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2), // Data
              1: FlexColumnWidth(2.5), // Desc / Beneficiario
              2: FlexColumnWidth(1.5), // Categoria / Metodo
              3: FlexColumnWidth(1.5), // Valor / Status
              4: FlexColumnWidth(1.0), // Acoes
            },
            border: const TableBorder(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              horizontalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
            children: [
              _buildTableHeader(['DATA', 'DESCRIÇÃO / FORNECEDOR', 'CATEGORIA / MEIO', 'VALOR / STATUS', 'AÇÕES']),
              ..._expenses.map((item) => _buildTableRow(item)),
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
            textAlign: index == 3 ? TextAlign.right : (index == 4 ? TextAlign.center : TextAlign.left),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        );
      }).toList(),
    );
  }

  TableRow _buildTableRow(ExpenseModel item) {
    Widget statusBadge;
    
    switch (item.status) {
      case 'APPROVED':
        statusBadge = const Text('APROVADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green));
        break;
      case 'REJECTED':
        statusBadge = const Text('REJEITADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red));
        break;
      case 'REVERSED':
        statusBadge = const Text('ESTORNADA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange));
        break;
      case 'PENDING':
      default:
        statusBadge = const Text('PENDENTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)));
        break;
    }

    const valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Color(0xFF0F172A),
      fontFamily: 'monospace',
    );

    return TableRow(
      children: [
        // 1. Data
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(item.date, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        // 2. Descricao / Fornecedor
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              Text('Beneficiário: ${item.supplier}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              if (item.receiptReference.isNotEmpty)
                Text('Ref: ${item.receiptReference}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),

            ],
          ),
        ),
        // 3. Categoria / Meio de Pagamento
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.category, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              const SizedBox(height: 2),
              Text(item.paymentMethod, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        // 4. Valor / Status
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('CHF ${_formatCHF(item.amount)}', textAlign: TextAlign.right, style: valueStyle),
              const SizedBox(height: 2),
              statusBadge,
            ],
          ),
        ),
        // 5. Acoes
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.status == 'PENDING' && _isAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                  tooltip: 'Aprovar',
                  onPressed: () => _handleApprove(item),
                ),
                IconButton(
                  icon: const Icon(Icons.highlight_off, size: 18, color: Colors.red),
                  tooltip: 'Rejeitar',
                  onPressed: () => _showRejectionDialog(item),
                ),
              ],
              if (item.status != 'REVERSED')
                IconButton(
                  icon: const Icon(Icons.undo_outlined, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'Estornar',
                  onPressed: () => _showReversalDialog(item),
                ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
                tooltip: 'Detalhes',
                onPressed: () => _showExpenseDetailsDialog(item),
              ),
            ],
          ),
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

  void _showExpenseDetailsDialog(ExpenseModel item) {
    String fmtDate(DateTime? dt) {
      if (dt == null) return '-';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    Widget buildRow(String label, String? value) {
      if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)))),
          ],
        ),
      );
    }

    Widget buildSection(String title) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
    );

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Detalhes da despesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSection('Dados Principais'),
                  buildRow('Criado por', item.createdBy.isNotEmpty ? item.createdBy : null),
                  buildRow('Data', item.date),
                  buildRow('Descrição', item.description),
                  buildRow('Beneficiário', item.supplier),
                  buildRow('Categoria', item.category),
                  buildRow('Meio de pagamento', item.paymentMethod),
                  buildRow('Referência', item.receiptReference.isNotEmpty ? item.receiptReference : null),
                  buildRow('Observações', item.observations),
                  buildSection('Histórico'),
                  // PENDING: sem campos de histórico adicionais
                  // APPROVED
                  buildRow('Aprovado por', item.approvedBy),
                  buildRow('Data de aprovação', fmtDate(item.approvalDate)),
                  // REJECTED
                  buildRow('Rejeitado por', item.rejectedBy),
                  buildRow('Data de rejeição', item.rejectionDate != null ? fmtDate(item.rejectionDate) : null),
                  buildRow('Justificativa da rejeição', item.rejectionJustification),
                  // REVERSED
                  buildRow('Estornado por', item.reversedBy),
                  buildRow('Data de estorno', item.reversalDate != null ? fmtDate(item.reversalDate) : null),
                  buildRow('Justificativa do estorno', item.reversalJustification),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Fechar'),
              onPressed: () => Navigator.of(dlgContext).pop(),
            ),
          ],
        );
      },
    );
  }
}
