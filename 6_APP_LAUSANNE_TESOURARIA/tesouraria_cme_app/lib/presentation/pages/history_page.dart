import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../services/fechamento_api_service.dart';
import '../../services/auth_api_service.dart';
import '../../domain/service_closing_history_models.dart';
import '../blocs/history_bloc.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'login_page.dart';
import 'closing_detail_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoryBloc(FechamentoApiService())..add(LoadHistoryEvent()),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'fechamentos'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Fechamentos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
          if (state is HistoryError && state.isUnauthorized) {
            AuthApiService().logout().then((_) {
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            });
          } else if (state is HistoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.excludeRed),
            );
          }
        },
        builder: (context, state) {
          Widget content;

          if (state is HistoryLoading || state is HistoryInitial) {
            content = const Center(child: CircularProgressIndicator());
          } else if (state is HistoryLoaded) {
            content = _buildLoadedBody(context, state.history, isDesktop);
          } else if (state is HistoryError) {
            content = _buildErrorState(context);
          } else {
            content = const Center(child: CircularProgressIndicator());
          }

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSidebarDrawer(activeRoute: 'fechamentos', permanent: true),
                Expanded(child: content),
              ],
            );
          }

          return content;
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'Falha ao carregar histórico',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifique sua conexão e tente novamente.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<HistoryBloc>().add(LoadHistoryEvent()),
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

  Widget _buildLoadedBody(BuildContext context, List<ServiceClosingSummary> history, bool isDesktop) {
    // Calculate totals for summary cards
    final totalCultos = history.length;
    final totalArrecadado = history.fold(0.0, (sum, item) => sum + item.physicalTotal);
    final mediaCulto = totalCultos > 0 ? totalArrecadado / totalCultos : 0.0;

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(isDesktop),
                const SizedBox(height: 32),

                // Summary Cards
                _buildSummaryCards(totalCultos, totalArrecadado, mediaCulto, isDesktop),
                const SizedBox(height: 32),

                // History Table
                _buildHistoryTable(context, history),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile layout
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isDesktop),
          const SizedBox(height: 24),
          _buildSummaryCards(totalCultos, totalArrecadado, mediaCulto, isDesktop),
          const SizedBox(height: 24),
          _buildHistoryList(context, history),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
          const Text(
            'HISTÓRICO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Fechamentos de Culto',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Registro completo de todos os cultos finalizados.',
          style: TextStyle(
            fontSize: isDesktop ? 13 : 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(int totalCultos, double totalArrecadado, double mediaCulto, bool isDesktop) {
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
        child: Text(
          '$totalCultos cultos finalizados  ·  Total CHF ${totalArrecadado.toStringAsFixed(2)}  ·  Média CHF ${mediaCulto.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
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
            _buildMobileSummaryRow('Cultos Registrados', '$totalCultos'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            _buildMobileSummaryRow('Total Arrecadado', 'CHF ${totalArrecadado.toStringAsFixed(2)}'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            _buildMobileSummaryRow('Média por Culto', 'CHF ${mediaCulto.toStringAsFixed(2)}'),
          ],
        ),
      );
    }
  }

  Widget _buildMobileSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.institutionalBlue,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTable(BuildContext context, List<ServiceClosingSummary> history) {
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
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text('DATA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                ),
                Expanded(
                  child: Text('TESOUREIRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                ),
                Expanded(
                  child: Text('CONFERENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                ),
                SizedBox(
                  width: 160,
                  child: Text('TOTAL FÍSICO', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),

          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Nenhum fechamento encontrado.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) => _buildTableRow(context, history[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, ServiceClosingSummary item) {
    final verifierText = (item.verifierName != null && item.verifierName!.isNotEmpty && item.verifierName != '-')
        ? item.verifierName!
        : '-';

    return InkWell(
      onTap: () async {
        final shouldReload = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClosingDetailPage(closingId: item.id)),
        );
        if (shouldReload == true && context.mounted) {
          context.read<HistoryBloc>().add(LoadHistoryEvent());
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Date as simple text standard DD/MM/AAAA
            SizedBox(
              width: 110,
              child: Text(
                item.serviceDate,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            // Treasurer
            Expanded(
              child: Text(
                item.mainTreasurer,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Verifier (Conferente)
            Expanded(
              child: Text(
                verifierText,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Total
            SizedBox(
              width: 160,
              child: Text(
                'CHF ${item.physicalTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Discreet arrow icon
            const SizedBox(
              width: 40,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<ServiceClosingSummary> history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Nenhum fechamento encontrado.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TODOS OS FECHAMENTOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) => _buildMobileRow(context, history[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileRow(BuildContext context, ServiceClosingSummary item) {
    String shortDate = item.serviceDate;
    try {
      final parts = item.serviceDate.split('/');
      if (parts.length == 3) {
        final day = parts[0];
        final month = int.tryParse(parts[1]) ?? 1;
        const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
        shortDate = "$day / ${months[month - 1]}".toUpperCase();
      }
    } catch (_) {}

    return InkWell(
      onTap: () async {
        final shouldReload = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClosingDetailPage(closingId: item.id)),
        );
        if (shouldReload == true && context.mounted) {
          context.read<HistoryBloc>().add(LoadHistoryEvent());
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                shortDate,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.mainTreasurer,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'CHF ${item.physicalTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}
