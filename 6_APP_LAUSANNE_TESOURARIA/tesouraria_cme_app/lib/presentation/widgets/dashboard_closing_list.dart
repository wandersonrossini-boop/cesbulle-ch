import 'package:flutter/material.dart';
import '../../domain/service_closing_history_models.dart';
import '../pages/closing_detail_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/history_bloc.dart';

class DashboardClosingList extends StatelessWidget {
  final List<ServiceClosingSummary> history;

  const DashboardClosingList({
    super.key,
    required this.history,
  });

  void _onItemTap(BuildContext context, int itemId) async {
    final shouldReload = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClosingDetailPage(closingId: itemId),
    ));
    if (shouldReload == true && context.mounted) {
      context.read<HistoryBloc>().add(LoadHistoryEvent());
    }
  }

  Widget _buildStatusBadge({bool small = false}) {
    return Text(
      'Fechado',
      style: TextStyle(
        color: const Color(0xFF137333),
        fontSize: small ? 10 : 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  'Últimos fechamentos',
                  style: TextStyle(
                    fontSize: isWide ? 15 : 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              if (isWide && history.isNotEmpty) ...[
                Container(
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'DATA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'TESOUREIRO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'TOTAL',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'STATUS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ],
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Nenhum fechamento registrado.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length > 5 ? 5 : history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final rawDate = item.serviceDate.isNotEmpty && item.serviceDate != '-' ? item.serviceDate : 'Culto sem data';
                    String dateStr = rawDate;
                    try {
                      final parts = rawDate.split('/');
                      if (parts.length == 3) {
                        final day = parts[0];
                        final month = int.tryParse(parts[1]) ?? 1;
                        const months = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
                        dateStr = "$day / ${months[month - 1]}";
                      }
                    } catch (_) {}

                    if (isWide) {
                      return InkWell(
                        onTap: () => _onItemTap(context, item.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.mainTreasurer,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'CHF ${item.physicalTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildStatusBadge(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'CHF ${item.physicalTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.mainTreasurer,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              _buildStatusBadge(small: true),
                            ],
                          ),
                        ),
                        onTap: () => _onItemTap(context, item.id),
                      );
                    }
                  },
                ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve: Listagem completa de fechamentos')),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF137333),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Ver todos os fechamentos →'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
