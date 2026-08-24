import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/service_closing_bloc.dart';
import '../blocs/service_closing_events_states.dart';
import '../../domain/envelope.dart';
import '../../core/monetary_utils.dart';
import '../../core/theme.dart';
import '../../services/draft_service.dart';
import '../../services/fechamento_api_service.dart';
import '../../services/auth_api_service.dart';
import '../../services/contributor_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ClosingPhase { setup, counting, review }

class WizardPage extends StatefulWidget {
  const WizardPage({super.key});

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  final TextEditingController _coTreasurerController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _verifierNameController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

  final ContributorApiService _contributorApiService = ContributorApiService();
  List<ContributorModel> _contributors = [];
  int? _selectedContributorId;

  bool _isTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  ClosingPhase _phase = ClosingPhase.setup;
  EnvelopeType _selectedType = EnvelopeType.dizimo;
  DateTime _selectedDate = DateTime.now();
  String _keyboardBuffer = '0';
  late final ServiceClosingBloc _bloc;
  final DraftService _draftService = DraftService();
  Timer? _syncTimer;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _typeController = TextEditingController();
  bool _isConnecting = false;
  bool _isMemberSelectorOpen = false;

  bool _isTimeValid() {
    if (_startTime == null || _endTime == null) return false;
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    return endMin > startMin;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  bool _isLoadingStatus = true;
  Map<String, dynamic>? _currentStatus;
  List<dynamic> _pendingOccurrences = [];

  Future<void> _checkCurrentStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStatus = true;
    });
    try {
      final status = await FechamentoApiService().getCurrentSessionStatus();
      List<dynamic> occurrences = [];
      if (!(status['hasSchedule'] ?? false)) {
        // Query pending occurrences for the last 7 days when no active automatic session is available
        occurrences = await FechamentoApiService().fetchPendingOccurrences(7);
      }
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _pendingOccurrences = occurrences;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _bloc = ServiceClosingBloc()..add(LoadMembersEvent());
    _checkCurrentStatus();
    _loadContributorsForSelection();
  }

  Future<void> _loadContributorsForSelection() async {
    try {
      final list = await _contributorApiService.fetchContributors();
      if (mounted) {
        setState(() {
          _contributors = list;
        });
      }
    } catch (_) {}
  }

  Future<String> _getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username') ?? "Tesoureiro";
    return savedUser.substring(0, 1).toUpperCase() + savedUser.substring(1);
  }

  void _initializeCleanSession(
    int? sessionId,
    DateTime date,
    String userName,
    String startTime,
    String endTime,
    String? type,
  ) {
    _bloc.add(
      InitializeClosingContextEvent(
        date,
        userName,
        '',
        sessionId: sessionId,
        serviceTime: startTime,
        serviceEndTime: endTime,
        serviceType: type,
      )
    );
    setState(() {
      _phase = ClosingPhase.counting;
      _isConnecting = false;
    });
    _startSyncTimer();
  }

  // ignore: unused_element
  Future<void> _checkLocalDraftFallback() async {
    final draft = await _draftService.loadDraft();
    if (draft != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgContext) => AlertDialog(
          title: const Text("Contagem em Andamento"),
          content: const Text("Encontramos uma contagem local que não foi finalizada. Deseja retomá-la de onde parou?"),
          actions: [
            TextButton(
              onPressed: () {
                _draftService.clearDraft();
                Navigator.pop(dlgContext);
              },
              child: const Text("DESCARTAR", style: TextStyle(color: AppTheme.excludeRed)),
            ),
            ElevatedButton(
              onPressed: () {
                _bloc.add(RestoreDraftEvent(draft));
                setState(() {
                  _selectedDate = draft.date ?? DateTime.now();
                  _coTreasurerController.text = draft.coTreasurer ?? "";
                  _verifierNameController.text = draft.verifierName ?? "";
                  _phase = ClosingPhase.counting;
                });
                Navigator.pop(dlgContext);
                _startSyncTimer();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.institutionalBlue, foregroundColor: Colors.white),
              child: const Text("RETOMAR"),
            ),
          ],
        ),
      );
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final serverDraft = await FechamentoApiService().getDraftFromServer();
        if (serverDraft != null && mounted && _phase == ClosingPhase.counting) {
          // Sync check ok
        }
        // Save local draft
        final state = _bloc.state;
        if (state.date != null && _phase == ClosingPhase.counting) {
          await _draftService.saveDraft(state);
        }
      } catch (e) {
        if (e.toString().contains('UNAUTHORIZED') && mounted) {
          timer.cancel();
          await AuthApiService().logout();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            );
          }
        }
        // Other network errors are silently ignored
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _coTreasurerController.dispose();
    _memberNameController.dispose();
    _verifierNameController.dispose();
    _keyboardFocusNode.dispose();
    _typeController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onKeyPress(String val) {
    setState(() {
      if (val == '⌫') {
        if (_keyboardBuffer.length > 1) {
          _keyboardBuffer = _keyboardBuffer.substring(0, _keyboardBuffer.length - 1);
        } else {
          _keyboardBuffer = '0';
        }
      } else if (val == '00') {
        if (_keyboardBuffer != '0') {
          _keyboardBuffer += '00';
        }
      } else {
        if (_keyboardBuffer == '0') {
          _keyboardBuffer = val;
        } else {
          _keyboardBuffer += val;
        }
      }
    });
  }

  int _getAmountFromBuffer() {
    return int.tryParse(_keyboardBuffer) ?? 0;
  }

  double _getDecimalAmountFromBuffer() {
    return BigDecimalConverter.fromRappen(_getAmountFromBuffer());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return BlocProvider.value(
      value: _bloc,
      child: Builder(
        builder: (context) {
          Widget bodyContent = BlocBuilder<ServiceClosingBloc, ServiceClosingState>(
            builder: (context, state) {
              switch (_phase) {
                case ClosingPhase.setup:
                  return _buildSetupPhase(context, state, isDesktop);
                case ClosingPhase.counting:
                  return _buildCountingPhase(context, state);
                case ClosingPhase.review:
                  return _buildReviewPhase(context, state);
              }
            },
          );

          // If we are on desktop and in the setup or counting phase, show sidebar side-by-side
          if (isDesktop && (_phase == ClosingPhase.setup || _phase == ClosingPhase.counting)) {
            bodyContent = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSidebarDrawer(activeRoute: 'fechamento', permanent: true),
                Expanded(child: bodyContent),
              ],
            );
          }

          return BlocListener<ServiceClosingBloc, ServiceClosingState>(
            listenWhen: (prev, curr) =>
                (curr.isSuccess && !prev.isSuccess) ||
                (curr.error != null && curr.error != prev.error),
            listener: (context, state) {
              if (state.isSuccess) {
                _syncTimer?.cancel();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              } else if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Erro ao enviar: ${state.error}'),
                  backgroundColor: AppTheme.excludeRed,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: Scaffold(
            backgroundColor: const Color(0xFFFAFAFA),
            appBar: (isDesktop && (_phase == ClosingPhase.setup || _phase == ClosingPhase.counting))
                ? null // Hide AppBar on desktop setup/counting phase to match dashboard and mock
                : AppBar(
                    backgroundColor: AppTheme.institutionalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: null,
                    title: Text(
                      _getAppBarTitle(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    leading: _phase != ClosingPhase.setup
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setState(() {
                                if (_phase == ClosingPhase.review) {
                                  _phase = ClosingPhase.counting;
                                  _startSyncTimer();
                                } else if (_phase == ClosingPhase.counting) {
                                  _syncTimer?.cancel();
                                  _phase = ClosingPhase.setup;
                                }
                              });
                            },
                          )
                        : null,
                  ),
            drawer: (isDesktop || _phase != ClosingPhase.setup)
                ? null
                : const AppSidebarDrawer(activeRoute: 'fechamento'),
            body: bodyContent,
            bottomNavigationBar: _phase == ClosingPhase.counting
                ? _buildCustomBottomBar()
                : null,
          ),
          );
        },
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_phase) {
      case ClosingPhase.setup: return "Novo fechamento";
      case ClosingPhase.counting: return "Contagem do culto";
      case ClosingPhase.review: return "Revisão e Fechamento";
    }
  }

  Widget _buildSetupPhase(BuildContext context, ServiceClosingState state, bool isDesktop) {
    if (_isLoadingStatus) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.institutionalBlue),
        ),
      );
    }

    final hasSchedule = _currentStatus?['hasSchedule'] ?? false;
    final hasSession = _currentStatus?['hasSession'] ?? false;
    final schedule = _currentStatus?['schedule'];
    final sessionMap = _currentStatus?['session'];

    String formatTime(String? timeStr) {
      if (timeStr == null) return '';
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
      }
      return timeStr;
    }

    IconData stateIcon;
    Color iconColor;
    String titleText;
    String descText;
    String buttonText;
    VoidCallback? onActionButtonPressed;

    if (!hasSchedule) {
      // Estado: Sem Culto
      stateIcon = Icons.event_busy_outlined;
      iconColor = const Color(0xFF64748B);
      titleText = "Nenhum Culto Programado";
      descText = "A detecção automática não identificou nenhum culto ativo na agenda para o momento atual.";
      buttonText = "VERIFICAR NOVAMENTE";
      onActionButtonPressed = _isConnecting ? null : () => _checkCurrentStatus();
    } else if (!hasSession) {
      // Estado: Iniciar
      stateIcon = Icons.play_circle_outline;
      iconColor = const Color(0xFF16A34A);
      titleText = "Iniciar Fechamento";
      descText = "${schedule['serviceType']} (${formatTime(schedule['startTime'])} - ${formatTime(schedule['endTime'])})";
      buttonText = "INICIAR CONTAGEM FÍSICA";
      onActionButtonPressed = _isConnecting ? null : () async {
        setState(() {
          _isConnecting = true;
        });
        try {
          final currentUserName = await _getCurrentUserName();
          final apiService = FechamentoApiService();
          final resolvedSession = await apiService.resolveAutomaticSession();
          
          final int? sessId = resolvedSession['id'] as int?;
          final DateTime sDate = DateTime.parse(resolvedSession['serviceDate'] as String);
          final String sStartTime = resolvedSession['serviceTime'] as String;
          final String sEndTime = resolvedSession['serviceEndTime'] as String;
          final String? sType = resolvedSession['serviceType'] as String?;

          _initializeCleanSession(
            sessId,
            sDate,
            currentUserName,
            sStartTime,
            sEndTime,
            sType,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao iniciar contagem: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isConnecting = false;
            });
          }
        }
      };
    } else {
      // Estado: Participar
      stateIcon = Icons.group_outlined;
      iconColor = const Color(0xFFEA580C);
      titleText = "Participar da Contagem";
      descText = "${schedule['serviceType']} (${formatTime(schedule['startTime'])} - ${formatTime(schedule['endTime'])})";
      buttonText = "RETOMAR/PARTICIPAR DA CONTAGEM";
      onActionButtonPressed = _isConnecting ? null : () async {
        setState(() {
          _isConnecting = true;
        });
        try {
          final currentUserName = await _getCurrentUserName();
          final apiService = FechamentoApiService();
          final resolvedSession = await apiService.resolveAutomaticSession();
          
          final int? sessId = resolvedSession['id'] as int?;
          final DateTime sDate = DateTime.parse(resolvedSession['serviceDate'] as String);
          final String sStartTime = resolvedSession['serviceTime'] as String;
          final String sEndTime = resolvedSession['serviceEndTime'] as String;
          final String? sType = resolvedSession['serviceType'] as String?;

          ServiceClosingState? sessionDraft;
          if (sessId != null) {
            try {
              sessionDraft = await apiService.getSessionDraftFromServer(sessId);
            } catch (_) {}
          }

          if (sessionDraft != null && mounted) {
            ServiceClosingState joinedDraft = sessionDraft;
            if (sessionDraft.mainTreasurer != currentUserName) {
              String newCoTreasurer = sessionDraft.coTreasurer ?? "";
              if (!newCoTreasurer.contains(currentUserName)) {
                newCoTreasurer = newCoTreasurer.isEmpty
                    ? currentUserName
                    : "$newCoTreasurer, $currentUserName";
              }
              joinedDraft = sessionDraft.copyWith(coTreasurer: newCoTreasurer);
            }

            final finalDraft = joinedDraft.copyWith(
              sessionId: sessId,
              date: sDate,
              serviceTime: sStartTime,
              serviceEndTime: sEndTime,
              serviceType: sType,
            );
            _bloc.add(RestoreDraftEvent(finalDraft));
            setState(() {
              _selectedDate = sDate;
              _coTreasurerController.text = finalDraft.coTreasurer ?? "";
              _verifierNameController.text = finalDraft.verifierName ?? "";
              _phase = ClosingPhase.counting;
            });
            _startSyncTimer();
          } else {
            _initializeCleanSession(
              sessId,
              sDate,
              currentUserName,
              sStartTime,
              sEndTime,
              sType,
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao participar: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isConnecting = false;
            });
          }
        }
      };
    }

    if (!hasSchedule) {
      return Container(
        color: const Color(0xFFFAFAFA),
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.event_busy_outlined, size: 72, color: Color(0xFF64748B)),
                      const SizedBox(height: 24),
                      const Text(
                        "Não há contagem disponível neste momento.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "As contagens são liberadas conforme a agenda de cultos.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (_pendingOccurrences.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          "Cultos anteriores sem contagem",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._pendingOccurrences.map((occ) {
                          final bool isResume = occ['sessionStatus'] != 'NO_SESSION';
                          final String rawDate = occ['date'];
                          // Parse date to format nicely (e.g. "Domingo, 23 de agosto")
                          String displayDateStr = rawDate;
                          try {
                            final parsedDate = DateTime.parse(rawDate);
                            // Simple formatting matching: Domingo, 23 de agosto
                            final weekday = const ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'][parsedDate.weekday - 1];
                            final month = const ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'][parsedDate.month - 1];
                            displayDateStr = "$weekday, ${parsedDate.day} de $month";
                          } catch (_) {}

                          final String timeRange = "${formatTime(occ['startTime'])} - ${formatTime(occ['endTime'])}";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    displayDateStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${occ['serviceType']} · $timeRange",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isConnecting ? null : () async {
                                      setState(() {
                                        _isConnecting = true;
                                      });
                                      try {
                                        final currentUserName = await _getCurrentUserName();
                                        final apiService = FechamentoApiService();
                                        
                                        // POST /session/late to start/resume late counting
                                        final resolvedSession = await apiService.createLateSession(
                                          occ['scheduleId'] as int,
                                          occ['date'] as String,
                                        );

                                        final int? sessId = resolvedSession['id'] as int?;
                                        final DateTime sDate = DateTime.parse(resolvedSession['serviceDate'] as String);
                                        final String sStartTime = resolvedSession['serviceTime'] as String;
                                        final String sEndTime = resolvedSession['serviceEndTime'] as String;
                                        final String? sType = resolvedSession['serviceType'] as String?;

                                        ServiceClosingState? sessionDraft;
                                        if (sessId != null && isResume) {
                                          try {
                                            sessionDraft = await apiService.getSessionDraftFromServer(sessId);
                                          } catch (_) {}
                                        }

                                        if (sessionDraft != null && mounted) {
                                          ServiceClosingState joinedDraft = sessionDraft;
                                          if (sessionDraft.mainTreasurer != currentUserName) {
                                            String newCoTreasurer = sessionDraft.coTreasurer ?? "";
                                            if (!newCoTreasurer.contains(currentUserName)) {
                                              newCoTreasurer = newCoTreasurer.isEmpty
                                                  ? currentUserName
                                                  : "$newCoTreasurer, $currentUserName";
                                            }
                                            joinedDraft = sessionDraft.copyWith(coTreasurer: newCoTreasurer);
                                          }

                                          final finalDraft = joinedDraft.copyWith(
                                            sessionId: sessId,
                                            date: sDate,
                                            serviceTime: sStartTime,
                                            serviceEndTime: sEndTime,
                                            serviceType: sType,
                                          );
                                          _bloc.add(RestoreDraftEvent(finalDraft));
                                          setState(() {
                                            _selectedDate = sDate;
                                            _coTreasurerController.text = finalDraft.coTreasurer ?? "";
                                            _verifierNameController.text = finalDraft.verifierName ?? "";
                                            _phase = ClosingPhase.counting;
                                          });
                                          _startSyncTimer();
                                        } else {
                                          _initializeCleanSession(
                                            sessId,
                                            sDate,
                                            currentUserName,
                                            sStartTime,
                                            sEndTime,
                                            sType,
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Erro ao iniciar contagem tardia: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isConnecting = false;
                                          });
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isResume ? const Color(0xFFEA580C) : AppTheme.institutionalBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      isResume ? "CONTINUAR CONTAGEM" : "REGISTRAR CONTAGEM",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFFAFAFA),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(stateIcon, size: 72, color: iconColor),
                    const SizedBox(height: 24),
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      descText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    if (hasSession && sessionMap != null && sessionMap['startedBy'] != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        "Iniciado por: ${sessionMap['startedBy']}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.institutionalBlue,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: onActionButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.institutionalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountingPhase(BuildContext context, ServiceClosingState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    if (!_keyboardFocusNode.hasFocus && !_isTextFieldFocused() && !_isMemberSelectorOpen) {
      _keyboardFocusNode.requestFocus();
    }
    
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_isTextFieldFocused()) return KeyEventResult.ignored;
        if (event is KeyDownEvent) {
          final logicalKey = event.logicalKey;
          if (logicalKey == LogicalKeyboardKey.digit0 || logicalKey == LogicalKeyboardKey.numpad0) {
            _onKeyPress('0');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit1 || logicalKey == LogicalKeyboardKey.numpad1) {
            _onKeyPress('1');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit2 || logicalKey == LogicalKeyboardKey.numpad2) {
            _onKeyPress('2');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit3 || logicalKey == LogicalKeyboardKey.numpad3) {
            _onKeyPress('3');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit4 || logicalKey == LogicalKeyboardKey.numpad4) {
            _onKeyPress('4');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit5 || logicalKey == LogicalKeyboardKey.numpad5) {
            _onKeyPress('5');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit6 || logicalKey == LogicalKeyboardKey.numpad6) {
            _onKeyPress('6');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit7 || logicalKey == LogicalKeyboardKey.numpad7) {
            _onKeyPress('7');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit8 || logicalKey == LogicalKeyboardKey.numpad8) {
            _onKeyPress('8');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.digit9 || logicalKey == LogicalKeyboardKey.numpad9) {
            _onKeyPress('9');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.backspace || logicalKey == LogicalKeyboardKey.delete) {
            _onKeyPress('⌫');
            return KeyEventResult.handled;
          } else if (logicalKey == LogicalKeyboardKey.enter) {
            _registerEntry(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: const Color(0xFFFAFAFA),
        width: double.infinity,
        height: double.infinity,
        child: isDesktop
            ? SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: _buildDesktopCountingLayout(context, state),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: _buildMobileCountingLayout(context, state),
              ),
      ),
    );
  }

  Widget _buildMobileCountingLayout(BuildContext context, ServiceClosingState state) {
    final double total = BigDecimalConverter.fromRappen(state.identifiedTotal + state.anonymousTotal);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Contribuinte button and Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Contribuinte clickable text
              InkWell(
                onTap: () => _showContributorSelector(context, state, false),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 16,
                        color: _memberNameController.text.isNotEmpty ? AppTheme.institutionalBlue : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _memberNameController.text.isNotEmpty 
                            ? _memberNameController.text 
                            : "Contribuinte (opcional)",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _memberNameController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          color: _memberNameController.text.isNotEmpty ? AppTheme.institutionalBlue : const Color(0xFF64748B),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Total",
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "CHF ${total.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Card VALOR
          _buildValorCard(),
          const SizedBox(height: 12),
          
          // Keyboard Grid
          _buildKeyboardGrid(false),
          const SizedBox(height: 12),
          
          // Button REGISTRAR
          _buildRegisterButton(context),
          const SizedBox(height: 8),
          
          // Ir para revisão
          _buildReviewLink(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDesktopCountingLayout(BuildContext context, ServiceClosingState state) {
    final double total = BigDecimalConverter.fromRappen(state.identifiedTotal + state.anonymousTotal);
    final allEntries = [
      ...state.identifiedEntries.map((e) => _SessionEntryItem(
        title: e.memberName,
        type: e.type.name.toUpperCase(),
        amount: BigDecimalConverter.fromRappen(e.amount),
        isAnonymous: false,
        id: e.id,
      )),
      ...state.anonymousEntries.map((e) => _SessionEntryItem(
        title: 'Anônimo',
        type: e.type.name.toUpperCase(),
        amount: BigDecimalConverter.fromRappen(e.amount),
        isAnonymous: true,
        id: e.id,
      )),
    ];
    
    // Sort recent first
    allEntries.sort((a, b) => b.id.compareTo(a.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of counting
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Contagem do culto",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  const Text(
                    "Total ",
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  Text(
                    "CHF ${total.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Two column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main column (Keyboard, valor, selector)
              Container(
                width: 380,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Contribuinte selector
                    InkWell(
                      onTap: () => _showContributorSelector(context, state, true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _memberNameController.text.isNotEmpty 
                                  ? _memberNameController.text 
                                  : "Contribuinte (opcional)",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _memberNameController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                  color: _memberNameController.text.isNotEmpty ? AppTheme.institutionalBlue : const Color(0xFF64748B),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Card VALOR
                    _buildValorCard(),
                    const SizedBox(height: 16),
                    
                    // Custom numeric keyboard
                    _buildKeyboardGrid(true),
                    const SizedBox(height: 16),
                    
                    // Registrar button
                    _buildRegisterButton(context),
                    const SizedBox(height: 12),
                    
                    // Ir para revisão
                    _buildReviewLink(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              
              // Secondary column (Últimos Lançamentos)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Últimos lançamentos",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (allEntries.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _undoLastGlobalEntry(context, state),
                              icon: const Icon(Icons.undo, size: 14),
                              label: const Text("Desfazer último", style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.excludeRed,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (allEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Text(
                              "Nenhum lançamento nesta sessão.",
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: allEntries.length > 5 ? 5 : allEntries.length,
                          separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final entry = allEntries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.type,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "CHF ${entry.amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1931),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("VALOR", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
          Text(
            "CHF ${_getDecimalAmountFromBuffer().toStringAsFixed(2)}", 
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardGrid(bool isDesktop) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: isDesktop ? 1.9 : 1.7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', '⌫'];
        String key = keys[index];
        bool isBackspace = key == '⌫';
        
        return ElevatedButton(
          onPressed: () => _onKeyPress(key),
          style: ElevatedButton.styleFrom(
            backgroundColor: isBackspace ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
            foregroundColor: isBackspace ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            elevation: 0,
            padding: EdgeInsets.zero,
          ),
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, size: 20)
              : Text(key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _registerEntry(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.institutionalBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: const Text("Registrar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
    );
  }

  Widget _buildReviewLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          _syncTimer?.cancel();
          setState(() => _phase = ClosingPhase.review);
        },
        child: const Text("Ir para revisão →", style: TextStyle(color: AppTheme.institutionalBlue, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCustomBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: EnvelopeType.values.map((type) {
            final isSelected = _selectedType == type;
            final label = type == EnvelopeType.dizimo 
                ? 'DÍZIMO' 
                : type == EnvelopeType.oferta 
                    ? 'OFERTA' 
                    : 'VOTO';
                    
            return Expanded(
              child: Material(
                color: isSelected ? AppTheme.institutionalBlue : Colors.white,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                    });
                  },
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 24,
                            height: 2,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showContributorSelector(BuildContext context, ServiceClosingState state, bool isDesktop) async {
    String filterText = "";
    
    setState(() {
      _isMemberSelectorOpen = true;
    });

    Widget selectorContent(StateSetter setDialogState) {
      return BlocBuilder<ServiceClosingBloc, ServiceClosingState>(
        builder: (context, currentState) {
          final filteredContributors = _contributors
              .where((c) => c.fullName.toLowerCase().contains(filterText.toLowerCase()) || c.contributorNumber.contains(filterText))
              .toList();
          return Container(
            constraints: const BoxConstraints(maxHeight: 350),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: TextField(
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: "Buscar contribuinte...",
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        filterText = val;
                      });
                    },
                  ),
                ),
                const Divider(),
                Expanded(
                  child: filteredContributors.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Nenhum contribuinte encontrado", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                if (filterText.trim().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _memberNameController.text = filterText.trim();
                                        _selectedContributorId = null;
                                      });
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text('Usar "${filterText.trim()}"'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.institutionalBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredContributors.length,
                          itemBuilder: (context, index) {
                            final contributor = filteredContributors[index];
                            return ListTile(
                              title: Text(contributor.fullName, style: const TextStyle(fontSize: 14)),
                              subtitle: Text('Nº ${contributor.contributorNumber} • ${contributor.city}', style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                setState(() {
                                  _memberNameController.text = contributor.fullName;
                                  _selectedContributorId = int.tryParse(contributor.id);
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
                if (_memberNameController.text.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.clear, color: AppTheme.excludeRed),
                    title: const Text("Remover / Tornar Anônimo", style: TextStyle(color: AppTheme.excludeRed, fontWeight: FontWeight.bold, fontSize: 13)),
                    onTap: () {
                      setState(() {
                        _memberNameController.clear();
                        _selectedContributorId = null;
                      });
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          );
        },
      );
    }

    try {
      if (isDesktop) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return BlocProvider.value(
              value: _bloc,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: selectorContent(setDialogState),
                    );
                  },
                ),
              ),
            );
          },
        );
      } else {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (sheetContext) {
            return BlocProvider.value(
              value: _bloc,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: selectorContent(setDialogState),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      }
    } finally {
      setState(() {
        _isMemberSelectorOpen = false;
      });
      _keyboardFocusNode.requestFocus();
    }
  }

  void _registerEntry(BuildContext context) {
    final memberName = _memberNameController.text.trim();
    final int rappen = _getAmountFromBuffer();
    
    if (rappen <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Por favor, digite um valor maior que zero."),
      ));
      return;
    }

    if (memberName.isNotEmpty) {
      final entryId = DateTime.now().microsecondsSinceEpoch.toString();
      final envelope = Envelope(
        id: entryId,
        memberName: memberName,
        type: _selectedType,
        amount: rappen,
        contributorId: _selectedContributorId,
      );
      context.read<ServiceClosingBloc>().add(AddEnvelopeEvent(envelope));
    } else {
      // Anonymous
      final entry = AnonymousEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _selectedType,
        amount: rappen,
      );
      context.read<ServiceClosingBloc>().add(AddAnonymousOfferingEvent(entry));
    }

    _memberNameController.clear();
    _selectedContributorId = null;
    setState(() {
      _keyboardBuffer = '0';
    });
  }

  void _undoLastGlobalEntry(BuildContext context, ServiceClosingState state) {
    String? latestIdentifiedId;
    int latestIdentifiedTime = 0;
    if (state.identifiedEntries.isNotEmpty) {
      latestIdentifiedId = state.identifiedEntries.last.id;
      latestIdentifiedTime = int.tryParse(latestIdentifiedId) ?? 0;
    }

    String? latestAnonymousId;
    int latestAnonymousTime = 0;
    if (state.anonymousEntries.isNotEmpty) {
      latestAnonymousId = state.anonymousEntries.last.id;
      latestAnonymousTime = int.tryParse(latestAnonymousId) ?? 0;
    }

    if (latestIdentifiedTime == 0 && latestAnonymousTime == 0) return;

    if (latestIdentifiedTime > latestAnonymousTime) {
      _bloc.add(UndoAddedEntryEvent(latestIdentifiedId!));
    } else {
      _bloc.add(UndoAnonymousOfferingEvent(latestAnonymousId!));
    }
  }

  Widget _buildReviewPhase(BuildContext context, ServiceClosingState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    String formattedDate = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(state.date ?? DateTime.now());
    if (formattedDate.isNotEmpty) {
      formattedDate = formattedDate.substring(0, 1).toUpperCase() + formattedDate.substring(1);
    }

    Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Lançamentos Identificados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
            Text("${state.identifiedEntries.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text("Contribuinte", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                    Expanded(child: Text("Categoria", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                    Expanded(child: Text("Valor", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              if (state.identifiedEntries.isEmpty)
                const Padding(padding: EdgeInsets.all(24.0), child: Center(child: Text("Nenhum lançamento identificado.", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))))
              else
                ...state.identifiedEntries.reversed.take(6).map((env) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(env.memberName, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                            Expanded(child: Text(env.type.name.toUpperCase(), style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('CHF ${BigDecimalConverter.fromRappen(env.amount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => context.read<ServiceClosingBloc>().add(RemoveEnvelopeEvent(env.id)),
                                    child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.excludeRed),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    ],
                  );
                }),
              if (state.identifiedEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: InkWell(
                      onTap: () => _showAllIdentifiedEntriesDialog(context, state),
                      child: const Text("Ver todos os lançamentos  >", style: TextStyle(color: AppTheme.institutionalBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("Lançamentos Anônimos por Categoria", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text("Categoria", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                    Expanded(child: Text("Quantidade", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                    Expanded(child: Text("Valor", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ...[EnvelopeType.dizimo, EnvelopeType.oferta, EnvelopeType.voto].map((type) {
                int count = state.anonymousEntries.where((e) => e.type == type).length;
                int amount = state.anonymousTotalBy(type);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(type.name.toUpperCase(), style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                          Expanded(child: Text("$count", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                          Expanded(child: Text('CHF ${BigDecimalConverter.fromRappen(amount).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                        ],
                      ),
                    ),
                    if (type != EnvelopeType.voto)
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ],
                );
              }),
              if (state.anonymousEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: InkWell(
                      onTap: () => _showAllAnonymousEntriesDialog(context, state),
                      child: const Text("Ver todos os lançamentos anônimos  >", style: TextStyle(color: AppTheme.institutionalBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Resumo da contagem", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _mathRow("Dízimos", state.identifiedTotalBy(EnvelopeType.dizimo) + state.anonymousTotalBy(EnvelopeType.dizimo), isBold: true),
                    const SizedBox(height: 12),
                    _mathRow("Ofertas Gerais (CHF)", state.identifiedTotalBy(EnvelopeType.oferta) + state.anonymousTotalBy(EnvelopeType.oferta), isBold: true),
                    const SizedBox(height: 12),
                    _mathRow("Votos / Missões (CHF)", state.identifiedTotalBy(EnvelopeType.voto) + state.anonymousTotalBy(EnvelopeType.voto), isBold: true),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total final consolidado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.institutionalBlue)),
                    Text("CHF ${BigDecimalConverter.fromRappen(state.registeredTotal).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.institutionalBlue)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("Conferência do caixa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _mathRow("Total registrado", state.registeredTotal),
              const SizedBox(height: 6),
              _mathRow("Total físico", state.physicalTotal),
              const SizedBox(height: 16),
              _mathRow(
                "Diferença", 
                state.difference, 
                isBold: true, 
                color: state.difference == 0 ? AppTheme.institutionalBlue : AppTheme.excludeRed
              ),
              if (state.difference != 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Text("A diferença deve ser zero para finalizar o fechamento.", style: TextStyle(color: AppTheme.excludeRed, fontSize: 11)),
                )
              else
                const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showPhysicalTotalDialog(context, state, isDesktop),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text("INFORMAR TOTAL FÍSICO"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.institutionalBlue,
                  side: const BorderSide(color: AppTheme.institutionalBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _verifierNameController,
          decoration: InputDecoration(
            labelText: "Conferente da contagem",
            hintText: "Digite o nome de quem conferiu",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (val) {
            setState(() {});
          },
        ),
        const SizedBox(height: 24),
        if (_verifierNameController.text.trim().toLowerCase() == state.mainTreasurer.trim().toLowerCase() && _verifierNameController.text.trim().isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              "O conferente deve ser uma pessoa diferente do responsável pela contagem.",
              style: TextStyle(color: AppTheme.excludeRed, fontSize: 13),
            ),
          ),
        ElevatedButton(
          onPressed: (state.error == null &&
                  !state.isSubmitting &&
                  state.difference == 0 &&
                  state.physicalTotal > 0 &&
                  _verifierNameController.text.trim().isNotEmpty &&
                  _verifierNameController.text.trim().toLowerCase() != state.mainTreasurer.trim().toLowerCase()) ? () {
            _syncTimer?.cancel();
            context.read<ServiceClosingBloc>().add(
              SubmitClosingEvent(
                verifierName: _verifierNameController.text.trim(),
                verifierType: "MANUAL",
              ),
            );
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.institutionalBlue, 
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            disabledForegroundColor: const Color(0xFF9CA3AF),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: state.isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Finalizar fechamento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.excludeRed, fontSize: 12)),
          ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Revisão e fechamento", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(formattedDate, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
          const SizedBox(height: 4),
          const Text("Confira os lançamentos e o total físico antes de finalizar o fechamento.", style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
          const SizedBox(height: 32),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: leftColumn),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: rightColumn),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rightColumn,
                const SizedBox(height: 32),
                leftColumn,
              ],
            ),
        ],
      ),
    );
  }

  void _showPhysicalTotalDialog(BuildContext context, ServiceClosingState state, bool isDesktop) {
    String localBuffer = '0';
    showDialog(
      context: context,
      builder: (dlgContext) {
        return BlocProvider.value(
          value: _bloc,
          child: StatefulBuilder(
          builder: (context, setDlgState) {
            void dlgKeyPress(String val) {
              setDlgState(() {
                if (val == '⌫') {
                  if (localBuffer.length > 1) {
                    localBuffer = localBuffer.substring(0, localBuffer.length - 1);
                  } else {
                    localBuffer = '0';
                  }
                } else if (val == '00') {
                  if (localBuffer != '0') {
                    localBuffer += '00';
                  }
                } else {
                  if (localBuffer == '0') {
                    localBuffer = val;
                  } else {
                    localBuffer += val;
                  }
                }
              });
            }

            double amount = BigDecimalConverter.fromRappen(int.tryParse(localBuffer) ?? 0);

            return Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  final logicalKey = event.logicalKey;
                  if (logicalKey == LogicalKeyboardKey.digit0 || logicalKey == LogicalKeyboardKey.numpad0) {
                    dlgKeyPress('0');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit1 || logicalKey == LogicalKeyboardKey.numpad1) {
                    dlgKeyPress('1');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit2 || logicalKey == LogicalKeyboardKey.numpad2) {
                    dlgKeyPress('2');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit3 || logicalKey == LogicalKeyboardKey.numpad3) {
                    dlgKeyPress('3');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit4 || logicalKey == LogicalKeyboardKey.numpad4) {
                    dlgKeyPress('4');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit5 || logicalKey == LogicalKeyboardKey.numpad5) {
                    dlgKeyPress('5');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit6 || logicalKey == LogicalKeyboardKey.numpad6) {
                    dlgKeyPress('6');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit7 || logicalKey == LogicalKeyboardKey.numpad7) {
                    dlgKeyPress('7');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit8 || logicalKey == LogicalKeyboardKey.numpad8) {
                    dlgKeyPress('8');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.digit9 || logicalKey == LogicalKeyboardKey.numpad9) {
                    dlgKeyPress('9');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.backspace || logicalKey == LogicalKeyboardKey.delete) {
                    dlgKeyPress('⌫');
                    return KeyEventResult.handled;
                  } else if (logicalKey == LogicalKeyboardKey.enter) {
                    context.read<ServiceClosingBloc>().add(SetPhysicalTotalEvent(int.tryParse(localBuffer) ?? 0));
                    Navigator.pop(dlgContext);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  width: isDesktop ? 360 : MediaQuery.of(context).size.width * 0.95,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total físico", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(dlgContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text("Dinheiro contado na mesa", style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(color: const Color(0xFF0B1931), borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Text("CHF ${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, 
                          childAspectRatio: 1.6, 
                          mainAxisSpacing: 12, 
                          crossAxisSpacing: 12
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', '⌫'];
                          String key = keys[index];
                          bool isBackspace = key == '⌫';
                          return ElevatedButton(
                            onPressed: () => dlgKeyPress(key),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isBackspace ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                              foregroundColor: isBackspace ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              padding: EdgeInsets.zero,
                            ),
                            child: isBackspace
                                ? const Icon(Icons.backspace_outlined, size: 22)
                                : Text(key, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dlgContext),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.institutionalBlue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text("CANCELAR", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<ServiceClosingBloc>().add(SetPhysicalTotalEvent(int.tryParse(localBuffer) ?? 0));
                                Navigator.pop(dlgContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.institutionalBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text("SALVAR TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
        );
      }
    );
  }

  Widget _buildCategoryReview(BuildContext context, ServiceClosingState state, EnvelopeType type, String title, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          _mathRow("Identificado", state.identifiedTotalBy(type)),
          const SizedBox(height: 4),
          _mathRow("Anônimo", state.anonymousTotalBy(type)),
          const SizedBox(height: 8),
          _mathRow("Subtotal", state.identifiedTotalBy(type) + state.anonymousTotalBy(type), isBold: true),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Divider(height: 1, color: Color(0xFFE5E7EB)),
            ),
        ],
      ),
    );
  }

  Widget _mathRow(String label, int amountRappen, {bool isBold = false, Color color = const Color(0xFF4B5563)}) {
    double amount = BigDecimalConverter.fromRappen(amountRappen);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13, color: color)),
        Text("CHF ${amount.toStringAsFixed(2)}", style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13, color: color)),
      ],
    );
  }

  void _showAllIdentifiedEntriesDialog(BuildContext context, ServiceClosingState state) {
    showDialog(
      context: context,
      builder: (dlgContext) {
        return BlocProvider.value(
          value: _bloc,
          child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Todos os Lançamentos Identificados (${state.identifiedEntries.length})",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(dlgContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFFF8FAFC),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text("Contribuinte", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                      Expanded(child: Text("Categoria", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                      Expanded(child: Text("Valor", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.identifiedEntries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, index) {
                      final env = state.identifiedEntries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(env.memberName, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                            Expanded(child: Text(env.type.name.toUpperCase(), style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('CHF ${BigDecimalConverter.fromRappen(env.amount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      context.read<ServiceClosingBloc>().add(RemoveEnvelopeEvent(env.id));
                                      Navigator.pop(dlgContext);
                                    },
                                    child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.excludeRed),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dlgContext),
                    child: const Text("FECHAR"),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  void _showAllAnonymousEntriesDialog(BuildContext context, ServiceClosingState state) {
    showDialog(
      context: context,
      builder: (dlgContext) {
        return BlocProvider.value(
          value: _bloc,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 600,
              constraints: const BoxConstraints(maxHeight: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Lançamentos Anônimos (${state.anonymousEntries.length})",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                        onPressed: () => Navigator.pop(dlgContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFFF8FAFC),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text("Categoria", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                        Expanded(child: Text("Valor", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.anonymousEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (context, index) {
                        final entry = state.anonymousEntries[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(entry.type.name.toUpperCase(), style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('CHF ${BigDecimalConverter.fromRappen(entry.amount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        context.read<ServiceClosingBloc>().add(UndoAnonymousOfferingEvent(entry.id));
                                        Navigator.pop(dlgContext);
                                      },
                                      child: const Tooltip(
                                        message: "Remover lançamento",
                                        child: Icon(Icons.delete_outline, size: 18, color: AppTheme.excludeRed),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dlgContext),
                      child: const Text("FECHAR"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionEntryItem {
  final String title;
  final String type;
  final double amount;
  final bool isAnonymous;
  final String id;

  _SessionEntryItem({
    required this.title,
    required this.type,
    required this.amount,
    required this.isAnonymous,
    required this.id,
  });
}
