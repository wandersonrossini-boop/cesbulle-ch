import 'package:flutter/material.dart';
import '../../services/draft_service.dart';
import '../../services/fechamento_api_service.dart';
import '../../services/user_api_service.dart';
import '../../services/service_schedule_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DraftService _draftService = DraftService();
  final FechamentoApiService _apiService = FechamentoApiService();
  final UserApiService _userApiService = UserApiService();
  final ServiceScheduleApiService _scheduleApiService = ServiceScheduleApiService();

  bool _isClearingDraft = false;
  bool _isAdmin = false;
  bool _isLoadingProfile = true;
  List<ServiceSchedule> _schedules = [];
  bool _isLoadingSchedules = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadSchedules();
  }

  Future<void> _checkRoleAndLoadSchedules() async {
    try {
      final profile = await _userApiService.getMyProfile();
      if (mounted) {
        setState(() {
          _isAdmin = profile.role.toUpperCase() == 'ADMIN';
          _isLoadingProfile = false;
        });
        if (_isAdmin) {
          _loadSchedules();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final data = await _scheduleApiService.listAll();
      if (mounted) {
        setState(() {
          _schedules = data;
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSchedules = false);
      }
    }
  }

  Future<void> _clearCurrentDraft() async {
    setState(() => _isClearingDraft = true);
    try {
      await _draftService.clearDraft();
      await _apiService.clearDraftOnServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rascunho de fechamento limpo com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao limpar rascunho: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingDraft = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'configuracoes'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Configurações',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) const AppSidebarDrawer(activeRoute: 'configuracoes', permanent: true),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(isDesktop),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: 'Congregação & Moeda',
                        icon: Icons.church_outlined,
                        children: [
                          _buildInfoRow('Congregação', 'CME Lausanne'),
                          _buildInfoRow('Moeda Padrão', 'CHF (Franco Suíço)'),
                          _buildInfoRow('Sub-unidade', 'Rappen (1 CHF = 100 Rappen)'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isAdmin) ...[
                        _buildSchedulesCard(),
                        const SizedBox(height: 20),
                      ],
                      _buildSectionCard(
                        title: 'Manutenção de Dados',
                        icon: Icons.cleaning_services_outlined,
                        children: [
                          const Text(
                            'Caso um fechamento em andamento fique travado ou com dados inconsistentes, você pode redefinir o rascunho.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _isClearingDraft ? null : _clearCurrentDraft,
                              icon: _isClearingDraft
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                              label: const Text('Limpar Rascunho de Fechamento', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: 'Servidor & Sistema',
                        icon: Icons.info_outline,
                        children: [
                          _buildInfoRow('API Backend', 'https://tesouraria-cme-api.onrender.com/api'),
                          _buildInfoRow('Versão do App', '1.2.0 (Release Lausanne)'),
                          _buildInfoRow('Ambiente', 'Produção (Firebase Hosting)'),
                        ],
                      ),
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

  Widget _buildHeader(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SISTEMA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configurações da Tesouraria',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Parâmetros do aplicativo e manutenção do sistema.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSchedulesCard() {
    return _buildSectionCard(
      title: 'Agenda de Cultos (Administrador)',
      icon: Icons.calendar_month_outlined,
      children: [
        if (_isLoadingSchedules)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else if (_schedules.isEmpty)
          const Text('Nenhum culto programado cadastrado.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))
        else
          Column(
            children: _schedules.map((schedule) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(schedule.serviceType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("${schedule.dayOfWeek} • ${schedule.startTime} - ${schedule.endTime}", style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: schedule.active,
                      activeColor: const Color(0xFF1E3A8A),
                      onChanged: (val) async {
                        try {
                          await _scheduleApiService.toggleActive(schedule.id);
                          _loadSchedules();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro ao alterar status: $e')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showScheduleDialog(schedule),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showScheduleDialog(null),
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar Culto Habitual'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _showScheduleDialog(ServiceSchedule? schedule) async {
    final isEdit = schedule != null;
    String selectedDay = schedule?.dayOfWeek ?? 'SUNDAY';
    final typeController = TextEditingController(text: schedule?.serviceType ?? '');
    TimeOfDay startTime = schedule != null
        ? TimeOfDay(
            hour: int.parse(schedule.startTime.split(':')[0]),
            minute: int.parse(schedule.startTime.split(':')[1]))
        : const TimeOfDay(hour: 19, minute: 0);
    TimeOfDay endTime = schedule != null
        ? TimeOfDay(
            hour: int.parse(schedule.endTime.split(':')[0]),
            minute: int.parse(schedule.endTime.split(':')[1]))
        : const TimeOfDay(hour: 21, minute: 0);

    final days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(isEdit ? 'Editar Culto Programado' : 'Cadastrar Culto Habitual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Dia da Semana'),
                  items: days
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedDay = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo/Nome do Culto',
                    hintText: 'Ex: Culto de Domingo Manhã',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: startTime);
                          if (picked != null) setDlgState(() => startTime = picked);
                        },
                        child: Text("Início: ${startTime.format(context)}"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: endTime);
                          if (picked != null) setDlgState(() => endTime = picked);
                        },
                        child: Text("Fim: ${endTime.format(context)}"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (typeController.text.trim().isEmpty) return;
                
                final startStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
                final endStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";

                try {
                  if (isEdit) {
                    await _scheduleApiService.update(
                      schedule.id,
                      dayOfWeek: selectedDay,
                      startTime: startStr,
                      endTime: endStr,
                      serviceType: typeController.text.trim(),
                      active: schedule.active,
                    );
                  } else {
                    await _scheduleApiService.create(
                      dayOfWeek: selectedDay,
                      startTime: startStr,
                      endTime: endStr,
                      serviceType: typeController.text.trim(),
                      active: true,
                    );
                  }
                  Navigator.pop(ctx);
                  _loadSchedules();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao salvar: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
