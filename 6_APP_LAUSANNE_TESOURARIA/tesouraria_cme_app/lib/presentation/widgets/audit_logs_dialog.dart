import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/audit_log_api_service.dart';

class AuditLogsDialog extends StatefulWidget {
  const AuditLogsDialog({super.key});

  @override
  State<AuditLogsDialog> createState() => _AuditLogsDialogState();
}

class _AuditLogsDialogState extends State<AuditLogsDialog> {
  final AuditLogApiService _apiService = AuditLogApiService();
  bool _isLoading = true;
  String? _errorMessage;
  AuditLogPageModel? _pageData;
  int _currentPage = 0;
  final int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.fetchAuditLogs(page: _currentPage, size: _pageSize);
      if (mounted) {
        setState(() {
          _pageData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatAction(String action) {
    switch (action) {
      case 'PERIOD_LOCKED':
        return 'Período Trancado';
      case 'PERIOD_UNLOCKED':
        return 'Período Reaberto';
      case 'EXPENSE_APPROVED':
        return 'Despesa Aprovada';
      case 'EXPENSE_REJECTED':
        return 'Despesa Rejeitada';
      case 'EXPENSE_REVERSED':
        return 'Despesa Estornada';
      case 'CLOSING_SUBMITTED':
        return 'Ata Submetida';
      case 'ATTESTATION_GENERATED':
        return 'Atestado Emitido';
      default:
        return action;
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('LOCKED') || action.contains('REJECTED') || action.contains('REVERSED')) {
      return const Color(0xFFDC2626); // Red
    }
    if (action.contains('APPROVED') || action.contains('UNLOCKED')) {
      return AppTheme.primaryGreen; // Green
    }
    return const Color(0xFF1E3A8A); // Blue / Official
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 28, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 12),
                    const Text(
                      'Trilha de Auditoria Administrativa',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Histórico de ações críticas realizadas por administradores e tesoureiros.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const Divider(height: 32, color: Color(0xFFE2E8F0)),
            Expanded(
              child: _buildContent(),
            ),
            if (_pageData != null && _pageData!.totalPages > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Página ${_currentPage + 1} de ${_pageData!.totalPages} (${_pageData!.totalElements} registros)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0
                            ? () {
                                setState(() => _currentPage--);
                                _loadLogs();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: !_pageData!.last
                            ? () {
                                setState(() => _currentPage++);
                                _loadLogs();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
        ),
      );
    }
    final logs = _pageData?.content ?? [];
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum log operacional registrado.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final log = logs[index];
        final actionColor = _getActionColor(log.action);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.timestamp.replaceAll('T', ' ').substring(0, 19),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Usuário: ${log.performedBy}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: actionColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _formatAction(log.action),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: actionColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.targetId != null && log.targetId != 'N/A')
                      Text(
                        'ID Alvo: ${log.targetId}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      log.details ?? '',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
