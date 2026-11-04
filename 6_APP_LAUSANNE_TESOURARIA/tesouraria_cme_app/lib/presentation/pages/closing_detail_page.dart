import '../widgets/attachment_uploader.dart';
import '../widgets/attachment_viewer_modal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../blocs/history_bloc.dart';
import '../../services/fechamento_api_service.dart';
import '../../core/theme.dart';
import '../../domain/service_closing_history_models.dart';
import '../../domain/envelope.dart';

class ClosingDetailPage extends StatelessWidget {
  final int closingId;

  const ClosingDetailPage({super.key, required this.closingId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoryBloc(FechamentoApiService())..add(LoadClosingDetailEvent(closingId)),
      child: ClosingDetailView(closingId: closingId),
    );
  }
}

class ClosingDetailView extends StatefulWidget {
  final int closingId;
  const ClosingDetailView({super.key, required this.closingId});

  @override
  State<ClosingDetailView> createState() => _ClosingDetailViewState();
}

class _ClosingDetailViewState extends State<ClosingDetailView> {
  String _userRole = '';
  List<dynamic> _closingAttachments = [];
  bool _isLoadingAttachments = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    final closingId = widget.closingId;
    setState(() { _isLoadingAttachments = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');
      final resp = await http.get(
        Uri.parse('$baseUrl/fechamento-culto/$closingId/attachments'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
        if (mounted) {
          setState(() {
            _closingAttachments = list;
            _isLoadingAttachments = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() { _isLoadingAttachments = false; });
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_role')?.toUpperCase() ?? '';
      });
    }
  }

  bool get _canRequestCorrection {
    return _userRole == 'ADMIN' || _userRole == 'PASTOR' || _userRole == 'TESOUREIRO';
  }

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
      ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
          if (state is HistoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.excludeRed),
            );
          } else if (state is HistoryCorrectionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.primaryGreen),
            );
          }
        },
        builder: (context, state) {
          if (state is HistoryDetailLoading || state is HistoryInitial || state is HistoryCorrectionSubmitting) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryDetailLoaded) {
            final detail = state.detail;
            final corrections = state.corrections;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, detail),
                      const SizedBox(height: 24),
                      if (corrections.isNotEmpty) ...[
                        _buildCorrectionsHistorySection(corrections),
                        const SizedBox(height: 24),
                      ],
                      _buildIdentifiedSection(detail),
                      const SizedBox(height: 24),
                      _buildUnidentifiedSection(detail),
                      const SizedBox(height: 24),
                      _buildAttachmentsSection(context, detail),
                      const SizedBox(height: 24),
                      _buildSummarySection(detail),
                      const SizedBox(height: 32),
                      _buildCorrectionActionArea(context, detail),
                    ],
                  ),
                ),
              ),
            );
          }
          return const Center(child: Text("Erro ao carregar detalhes."));
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ServiceClosingDetail detail) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Data do Culto: ${detail.serviceDate}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('CONFIRMADO', style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Tesoureiro Principal: ${detail.mainTreasurer}', style: const TextStyle(fontSize: 15, color: Color(0xFF334155))),
            const SizedBox(height: 4),
            Text('Conferente: ${detail.verifierName ?? detail.coTreasurer}', style: const TextStyle(fontSize: 15, color: Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionsHistorySection(List<ServiceClosingCorrectionItem> corrections) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFDE68A)),
      ),
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 8),
                Text('Histórico Auditado de Correções', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              ],
            ),
            const SizedBox(height: 12),
            ...corrections.map((corr) {
              final isPos = corr.difference >= 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Por: ${corr.correctedBy} em ${corr.createdAt}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        Text(
                          '${isPos ? "+" : ""}CHF ${corr.difference.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isPos ? AppTheme.primaryGreen : AppTheme.excludeRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Original: CHF ${corr.originalPhysicalTotal.toStringAsFixed(2)}  ➔  Corrigido: CHF ${corr.correctedPhysicalTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text('Motivo: ${corr.reason}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                  ],
                ),
              );
            }),
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
    final diff = detail.physicalTotal - detail.totalDinheiro;
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
            _summaryRow('Total em Dinheiro (Espécie)', detail.totalDinheiro),
            const SizedBox(height: 8),
            _summaryRow('TWINT', detail.totalTwint),
            const SizedBox(height: 8),
            _summaryRow('Transferências Bancárias', detail.totalTransferencias),
            const SizedBox(height: 8),
            _summaryRow('Total Eletrônico', detail.totalEletronico),
            const Divider(),
            _summaryRow('Total Geral Registrado', detail.registeredTotal, isBold: true),
            const SizedBox(height: 8),
            _summaryRow('Dinheiro Físico Contado', detail.physicalTotal, isBold: true),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diferença de Caixa (Dinheiro): CHF ${diff.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 17,
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

  Widget _buildCorrectionActionArea(BuildContext context, ServiceClosingDetail detail) {
    if (!_canRequestCorrection) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "A retificação de fechamentos confirmados requer autorização de Tesoureiro ou Administrador.",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _openCorrectionDialog(context, detail),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text("Solicitar Correção do Fechamento"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.institutionalBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "A correção exige justificativa formal e mantém registro inalterável do histórico anterior.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
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


  Widget _buildAttachmentsSection(BuildContext context, ServiceClosingDetail detail) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file, color: AppTheme.institutionalBlue, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Documentos e Comprovantes (${_closingAttachments.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                AttachmentUploader(
                  entityType: 'fechamento-culto',
                  entityId: detail.id.toString(),
                  onUploadSuccess: _loadAttachments,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingAttachments)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_closingAttachments.isEmpty)
              const Text(
                'Nenhum documento ou comprovante anexado a este culto.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _closingAttachments.map<Widget>((att) {
                  final attMap = att as Map<String, dynamic>;
                  final name = attMap['fileName'] ?? 'documento';
                  final isPdf = name.toLowerCase().endsWith('.pdf');
                  return InkWell(
                    onTap: () {
                      AttachmentViewerModal.viewAttachment(
                        context: context,
                        entityType: 'fechamento-culto',
                        entityId: detail.id.toString(),
                        attachmentId: attMap['id'].toString(),
                        fileName: name,
                        contentType: attMap['contentType'],
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            size: 16,
                            color: isPdf ? AppTheme.excludeRed : AppTheme.institutionalBlue,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
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

  void _openCorrectionDialog(BuildContext context, ServiceClosingDetail detail) {
    final reasonCtrl = TextEditingController();
    final dizimoCtrl = TextEditingController(text: detail.unidentifiedDizimoTotal.toStringAsFixed(2));
    final ofertaCtrl = TextEditingController(text: detail.unidentifiedOfertaTotal.toStringAsFixed(2));
    final votoCtrl = TextEditingController(text: detail.unidentifiedVotoTotal.toStringAsFixed(2));
    final physicalCtrl = TextEditingController(text: detail.physicalTotal.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final identifiedSum = detail.identifiedTotal;
            final dizVal = double.tryParse(dizimoCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final ofVal = double.tryParse(ofertaCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final votVal = double.tryParse(votoCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final physVal = double.tryParse(physicalCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final calcRegistered = identifiedSum + dizVal + ofVal + votVal;
            final isBalanced = (physVal - calcRegistered).abs() < 0.01;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_note, color: AppTheme.institutionalBlue),
                  SizedBox(width: 8),
                  Text("Solicitar Correção de Culto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Altere os valores necessários e forneça a justificativa obrigatória.",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Justificativa da Correção (obrigatória) *",
                          hintText: "Ex.: Erro de digitação na contagem de ofertas avulsas...",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                      const SizedBox(height: 16),
                      const Text("Valores Avulsos (Não Identificados):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dizimoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: "Dízimo Avulso", border: OutlineInputBorder()),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: ofertaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: "Oferta Avulsa", border: OutlineInputBorder()),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: votoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: "Voto Avulso", border: OutlineInputBorder()),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: physicalCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Total Físico Conferido (CHF)",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isBalanced ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isBalanced
                              ? "Total Registrado (CHF ${calcRegistered.toStringAsFixed(2)}) confere com o Total Físico."
                              : "Atenção: Total Registrado (CHF ${calcRegistered.toStringAsFixed(2)}) difere do Total Físico (CHF ${physVal.toStringAsFixed(2)}).",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isBalanced ? const Color(0xFF166534) : AppTheme.excludeRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgContext),
                  child: const Text("CANCELAR"),
                ),
                ElevatedButton(
                  onPressed: (reasonCtrl.text.trim().isNotEmpty && isBalanced)
                      ? () {
                          final reason = reasonCtrl.text.trim();
                          Navigator.pop(dlgContext);
                          context.read<HistoryBloc>().add(
                            RequestCorrectionEvent(
                              closingId: detail.id,
                              reason: reason,
                              physicalTotal: physVal,
                              unidentifiedDizimoTotal: dizVal,
                              unidentifiedOfertaTotal: ofVal,
                              unidentifiedVotoTotal: votVal,
                              identifiedEntries: detail.identifiedEntries,
                              verifierName: detail.verifierName,
                              verifierType: detail.verifierType,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.institutionalBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("SALVAR CORREÇÃO"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
