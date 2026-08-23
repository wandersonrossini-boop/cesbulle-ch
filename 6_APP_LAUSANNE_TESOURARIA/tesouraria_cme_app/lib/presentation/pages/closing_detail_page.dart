import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/history_bloc.dart';
import '../../services/fechamento_api_service.dart';
import '../../core/theme.dart';
import '../../domain/service_closing_history_models.dart';

class ClosingDetailPage extends StatelessWidget {
  final int closingId;

  const ClosingDetailPage({super.key, required this.closingId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoryBloc(FechamentoApiService())..add(LoadClosingDetailEvent(closingId)),
      child: const ClosingDetailView(),
    );
  }
}

class ClosingDetailView extends StatelessWidget {
  const ClosingDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espelho Oficial do Culto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar Relatório',
            onPressed: () {
              final state = context.read<HistoryBloc>().state;
              if (state is HistoryDetailLoaded) {
                _shareClosingDetails(state.detail);
              }
            },
          ),
        ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
          if (state is HistoryError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is HistoryDeleteSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fechamento excluído com sucesso.")));
            Navigator.of(context).pop(true); // Return true to refresh list
          }
        },
        builder: (context, state) {
          if (state is HistoryDetailLoading || state is HistoryInitial || state is HistoryDeleting) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryDetailLoaded) {
            final detail = state.detail;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(detail),
                  const SizedBox(height: 24),
                  _buildIdentifiedSection(detail),
                  const SizedBox(height: 24),
                  _buildUnidentifiedSection(detail),
                  const SizedBox(height: 24),
                  _buildSummarySection(detail),
                ],
              ),
            )));
          }
          return const Center(child: Text("Erro ao carregar detalhes."));
        },
      ),
    );
  }

  Widget _buildHeader(ServiceClosingDetail detail) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data do Culto: ${detail.serviceDate}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Tesoureiro Principal: ${detail.mainTreasurer}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Conferente: ${detail.verifierName ?? detail.coTreasurer}', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifiedSection(ServiceClosingDetail detail) {
    if (detail.identifiedEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Identificados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.institutionalBlue)),
        const SizedBox(height: 8),
        ...detail.identifiedEntries.map((e) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(e.memberName),
            subtitle: Text(e.type.name.toUpperCase()),
            trailing: Text('CHF ${(e.amount / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        )),
      ],
    );
  }

  Widget _buildUnidentifiedSection(ServiceClosingDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Não Identificados (Avulsos)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.institutionalBlue)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(title: const Text('Dízimo'), trailing: Text('CHF ${detail.unidentifiedDizimoTotal.toStringAsFixed(2)}')),
              const Divider(height: 1),
              ListTile(title: const Text('Oferta'), trailing: Text('CHF ${detail.unidentifiedOfertaTotal.toStringAsFixed(2)}')),
              const Divider(height: 1),
              ListTile(title: const Text('Voto'), trailing: Text('CHF ${detail.unidentifiedVotoTotal.toStringAsFixed(2)}')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(ServiceClosingDetail detail) {
    final diff = detail.physicalTotal - detail.registeredTotal;
    final isZero = diff.abs() < 0.01;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Total Identificado', detail.identifiedTotal),
            const SizedBox(height: 8),
            _summaryRow('Total Não Identificado', detail.unidentifiedTotal),
            const Divider(),
            _summaryRow('Total Registrado (Sistema)', detail.registeredTotal, isBold: true),
            const SizedBox(height: 8),
            _summaryRow('Total Físico (Conferido)', detail.physicalTotal, isBold: true),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diferença: CHF ${diff.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isZero ? AppTheme.primaryGreen : AppTheme.excludeRed,
                  ),
                ),
                if (isZero) const Icon(Icons.check_circle, color: AppTheme.primaryGreen)
                else const Icon(Icons.error, color: AppTheme.excludeRed)
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text('CHF ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  void _shareClosingDetails(ServiceClosingDetail detail) {
    final buffer = StringBuffer();
    final diff = detail.physicalTotal - detail.registeredTotal;

    buffer.writeln('FECHAMENTO DE CULTO — CME LAUSANNE');
    buffer.writeln();
    buffer.writeln('Data: ${detail.serviceDate}');
    buffer.writeln('Tesoureiro responsável: ${detail.mainTreasurer}');
    buffer.writeln('Conferente da contagem: ${detail.verifierName ?? detail.coTreasurer}');
    buffer.writeln();
    buffer.writeln('RESUMO FINANCEIRO');
    buffer.writeln();
    buffer.writeln('Total identificado: CHF ${detail.identifiedTotal.toStringAsFixed(2)}');
    buffer.writeln('Total não identificado: CHF ${detail.unidentifiedTotal.toStringAsFixed(2)}');
    buffer.writeln('Total físico conferido: CHF ${detail.physicalTotal.toStringAsFixed(2)}');
    buffer.writeln('Diferença: CHF ${diff.toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('Fechamento conferido e finalizado no sistema de Tesouraria CME Lausanne.');

    // ignore: deprecated_member_use
    Share.share(buffer.toString(), subject: 'Fechamento de Culto - ${detail.serviceDate}');
  }

  void _confirmDelete(BuildContext context, int closingId) {
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text("Excluir Fechamento", style: TextStyle(color: AppTheme.excludeRed)),
          content: const Text("Tem certeza? Esta ação apagará permanentemente o registro deste culto e todos os seus envelopes. Essa ação não pode ser desfeita."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgContext).pop(),
              child: const Text("CANCELAR"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dlgContext).pop();
                context.read<HistoryBloc>().add(DeleteClosingEvent(closingId));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.excludeRed),
              child: const Text("EXCLUIR DEFINITIVAMENTE"),
            ),
          ],
        );
      },
    );
  }
}
