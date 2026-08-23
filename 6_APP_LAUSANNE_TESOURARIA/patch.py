import re

path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\expenses_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# We want to replace the whole showAddEditRecurringDialog inside _showRecurringExpensesManager
# and use a unified state inside the StatefulBuilder.

# Let's extract _showRecurringExpensesManager and replace it.
old_func = re.search(r'void _showRecurringExpensesManager\(\) \{.*?Future<void> _viewAttachment', content, flags=re.DOTALL)
if old_func:
    func_text = old_func.group(0)
    # create new function
    new_func_text = '''void _showRecurringExpensesManager() {
    bool localLoading = true;
    List<RecurringExpenseModel> localRecurrings = [];
    bool isAddingOrEditing = false;
    RecurringExpenseModel? currentEditItem;
    
    // Form controllers
    final descController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController();
    String category = 'Utilidades';
    bool active = true;

    showDialog(
      context: context,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void loadLocalRecurrings() async {
              try {
                final list = await _apiService.getRecurringExpenses();
                if (mounted) {
                  setModalState(() {
                    localRecurrings = list;
                    localLoading = false;
                  });
                }
              } catch (e) {
                if (mounted) {
                  setModalState(() => localLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar recorrentes: '), backgroundColor: Colors.red));
                }
              }
            }

            if (localLoading && localRecurrings.isEmpty) {
              loadLocalRecurrings();
            }

            void showAddEditForm(RecurringExpenseModel? editItem) {
              setModalState(() {
                isAddingOrEditing = true;
                currentEditItem = editItem;
                descController.text = editItem?.description ?? '';
                amountController.text = editItem?.amount.toString() ?? '';
                dayController.text = editItem?.dueDayOfMonth.toString() ?? '1';
                category = editItem?.category ?? 'Utilidades';
                active = editItem?.active ?? true;
              });
            }

            if (isAddingOrEditing) {
              final isEdit = currentEditItem != null;
              return AlertDialog(
                title: Text(isEdit ? 'Editar Despesa Fixa' : 'Cadastrar Despesa Fixa', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Descricao', border: OutlineInputBorder()),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor (CHF)', border: OutlineInputBorder()),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Aluguel & Local', child: Text('Aluguel & Local')),
                          DropdownMenuItem(value: 'Utilidades', child: Text('Utilidades (Agua/Luz/Net)')),
                          DropdownMenuItem(value: 'Manutencao & Equipamento', child: Text('Manutencao & Equipamentos')),
                          DropdownMenuItem(value: 'Eventos & Ministerio', child: Text('Eventos & Ministerio')),
                          DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dia de Vencimento (1 a 31)', border: OutlineInputBorder()),
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Despesa Ativa?', style: TextStyle(fontSize: 13)),
                          value: active,
                          onChanged: (val) => setModalState(() => active = val),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => setModalState(() => isAddingOrEditing = false),
                    child: const Text('CANCELAR'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (descController.text.isEmpty || amountController.text.isEmpty || dayController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatorios.'), backgroundColor: Colors.red));
                        return;
                      }
                      
                      final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
                      final day = int.tryParse(dayController.text);
                      
                      if (amount == null || day == null || day < 1 || day > 31) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valores invalidos.'), backgroundColor: Colors.red));
                        return;
                      }
                      
                      setModalState(() {
                        localLoading = true;
                        isAddingOrEditing = false;
                      });
                      
                      try {
                        if (isEdit) {
                          await _apiService.updateRecurringExpense(
                            int.parse(currentEditItem!.id),
                            descController.text,
                            amount,
                            category,
                            day,
                            active,
                          );
                        } else {
                          await _apiService.createRecurringExpense(
                            descController.text,
                            amount,
                            category,
                            day,
                          );
                        }
                        loadLocalRecurrings();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: '), backgroundColor: Colors.red));
                        setModalState(() => localLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                    child: const Text('SALVAR'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Gerenciar Despesas Fixas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('As despesas fixas ativas serao geradas automaticamente no 1o dia de cada mes, com status PENDENTE.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    localLoading
                        ? const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()))
                        : localRecurrings.isEmpty
                            ? const Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text('Nenhuma despesa fixa cadastrada.', style: TextStyle(color: Color(0xFF94A3B8)))))
                            : Flexible(
                                child: Container(
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
                                  child: SingleChildScrollView(
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(2),
                                        1: FlexColumnWidth(1.2),
                                        2: FlexColumnWidth(1.2),
                                        3: FlexColumnWidth(0.8),
                                        4: IntrinsicColumnWidth(),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                                          children: [
                                            const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('DESPESA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('CATEGORIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('VALOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('DIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                            const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('ACOES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                          ],
                                        ),
                                        ...localRecurrings.map((rec) {
                                          return TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(rec.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                    const SizedBox(height: 2),
                                                    Text(rec.active ? 'ATIVA' : 'INATIVA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rec.active ? Colors.green : Colors.red)),
                                                  ],
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(rec.category, style: const TextStyle(fontSize: 12))),
                                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('CHF ', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Dia ', style: const TextStyle(fontSize: 12))),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                                      onPressed: () => showAddEditForm(rec),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                                      onPressed: () async {
                                                        setModalState(() => localLoading = true);
                                                        try {
                                                          await _apiService.deleteRecurringExpense(int.parse(rec.id));
                                                          loadLocalRecurrings();
                                                        } catch (e) {
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: '), backgroundColor: Colors.red));
                                                          setModalState(() => localLoading = false);
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => showAddEditForm(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar Despesa Fixa'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(modalContext),
                          child: const Text('FECHAR'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _viewAttachment'''
    content = content.replace(func_text, new_func_text)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched.")
else:
    print("Could not find function.")
