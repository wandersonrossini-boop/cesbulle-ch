import 'dart:async';
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
  final FocusNode _keyboardFocusNode = FocusNode();

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

  @override
  void initState() {
    super.initState();
    _bloc = ServiceClosingBloc()..add(LoadMembersEvent());
    _checkForDraft();
  }

  Future<String> _getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username') ?? "Tesoureiro";
    return savedUser.substring(0, 1).toUpperCase() + savedUser.substring(1);
  }

  Future<void> _checkForDraft() async {
    // Check server draft first to sync multi-device
    final serverDraft = await FechamentoApiService().getDraftFromServer();
    
    if (serverDraft != null && mounted) {
      final currentUserName = await _getCurrentUserName();
      
      // Auto-assign as co-treasurer if this user is not the main treasurer
      ServiceClosingState joinedDraft = serverDraft;
      if (serverDraft.mainTreasurer != currentUserName) {
        String newCoTreasurer = serverDraft.coTreasurer ?? "";
        if (!newCoTreasurer.contains(currentUserName)) {
          newCoTreasurer = newCoTreasurer.isEmpty 
              ? currentUserName 
              : "$newCoTreasurer, $currentUserName";
        }
        joinedDraft = serverDraft.copyWith(coTreasurer: newCoTreasurer);
        _bloc.add(InitializeClosingContextEvent(
          joinedDraft.date ?? DateTime.now(),
          joinedDraft.mainTreasurer,
          joinedDraft.coTreasurer ?? '',
        ));
      }
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgContext) => AlertDialog(
          title: const Text("Contagem Coletiva"),
          content: Text("Existe uma contagem ativa iniciada por ${joinedDraft.mainTreasurer} para o culto de ${joinedDraft.date != null ? DateFormat('dd/MM').format(joinedDraft.date!) : ''}. Deseja participar dela?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dlgContext);
                _checkLocalDraftFallback();
              },
              child: const Text("IGNORAR"),
            ),
            ElevatedButton(
              onPressed: () {
                _bloc.add(RestoreDraftEvent(joinedDraft));
                setState(() {
                  _selectedDate = joinedDraft.date ?? DateTime.now();
                  _coTreasurerController.text = joinedDraft.coTreasurer ?? "";
                  _phase = ClosingPhase.counting;
                });
                Navigator.pop(dlgContext);
                _startSyncTimer();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              child: const Text("PARTICIPAR"),
            ),
          ],
        ),
      );
      return;
    }

    _checkLocalDraftFallback();
  }

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
                  _phase = ClosingPhase.counting;
                });
                Navigator.pop(dlgContext);
                _startSyncTimer();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
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
          // A sincronização ativa de rascunho do servidor foi removida.
          // O timer serve agora apenas para verificar se a sessão continua válida (sem disparar UNAUTHORIZED).
          // O estado local é a fonte da verdade enquanto o usuário está digitando.
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
    _keyboardFocusNode.dispose();
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                    title: Text(
                      _getAppBarTitle(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
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
    // Format date: e.g. "Domingo, 09 de agosto de 2026"
    String formattedDate = DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(_selectedDate);
    if (formattedDate.isNotEmpty) {
      formattedDate = formattedDate.substring(0, 1).toUpperCase() + formattedDate.substring(1);
    }

    return Container(
      color: const Color(0xFFFAFAFA),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // CONTAGEM DE CULTO
                Text(
                  "CONTAGEM DE CULTO",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date text
                Text(
                  formattedDate,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 36 : 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                
                // Space between date and button
                SizedBox(height: isDesktop ? 100 : 80),
                
                // INICIAR button
                Container(
                  width: isDesktop ? 360 : double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0A2E6B), // dark navy
                        Color(0xFF0C53D4), // royal blue
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final currentUserName = await _getCurrentUserName();
                        if (context.mounted) {
                          context.read<ServiceClosingBloc>().add(
                            InitializeClosingContextEvent(_selectedDate, currentUserName, '')
                          );
                          setState(() => _phase = ClosingPhase.counting);
                          _startSyncTimer();
                        }
                      },
                      child: const Center(
                        child: Text(
                          "INICIAR",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Space between button and text
                const SizedBox(height: 48),
                
                // Explanatory text below
                Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: const Text(
                    "Ao iniciar, você poderá registrar os valores de dízimos, ofertas e votos e finalizar o fechamento.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountingPhase(BuildContext context, ServiceClosingState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    if (!_keyboardFocusNode.hasFocus && !_isTextFieldFocused()) {
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
                        color: _memberNameController.text.isNotEmpty ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _memberNameController.text.isNotEmpty 
                            ? _memberNameController.text 
                            : "Contribuinte (opcional)",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _memberNameController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          color: _memberNameController.text.isNotEmpty ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
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
                                  color: _memberNameController.text.isNotEmpty ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
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
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: const Text("REGISTRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
    );
  }

  Widget _buildReviewLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          _syncTimer?.cancel();
          setState(() => _phase = ClosingPhase.review);
        },
        child: const Text("Ir para revisão →", style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, fontWeight: FontWeight.bold)),
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
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
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

  void _showContributorSelector(BuildContext context, ServiceClosingState state, bool isDesktop) {
    String filterText = "";
    
    Widget selectorContent(StateSetter setDialogState) {
      return BlocBuilder<ServiceClosingBloc, ServiceClosingState>(
        builder: (context, currentState) {
          final filteredMembers = currentState.knownMembers
              .where((m) => m.toLowerCase().contains(filterText.toLowerCase()))
              .toList();
          return Container(
        constraints: const BoxConstraints(maxHeight: 350),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Pesquisar Contribuinte',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
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
              child: filteredMembers.isEmpty
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
                                  context.read<ServiceClosingBloc>().add(AddLocalMemberEvent(filterText));
                                  setState(() {
                                    _memberNameController.text = filterText.trim();
                                  });
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: Text('Adicionar "${filterText.trim()}"'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
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
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        return ListTile(
                          title: Text(member, style: const TextStyle(fontSize: 14)),
                          onTap: () {
                            setState(() {
                              _memberNameController.text = member;
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

    if (isDesktop) {
      showDialog(
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
      showModalBottomSheet(
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
      final envelope = Envelope(id: entryId, memberName: memberName, type: _selectedType, amount: rappen);
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
                      child: const Text("Ver todos os lançamentos  >", style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, fontWeight: FontWeight.w600)),
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
                    _buildCategoryReview(context, state, EnvelopeType.dizimo, "DÍZIMO"),
                    _buildCategoryReview(context, state, EnvelopeType.oferta, "OFERTA"),
                    _buildCategoryReview(context, state, EnvelopeType.voto, "VOTO", isLast: true),
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
                    const Text("TOTAL REGISTRADO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
                    Text("CHF ${BigDecimalConverter.fromRappen(state.registeredTotal).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
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
                color: state.difference == 0 ? const Color(0xFF1E3A8A) : AppTheme.excludeRed
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
                  foregroundColor: const Color(0xFF1E3A8A),
                  side: const BorderSide(color: Color(0xFF1E3A8A)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _coTreasurerController.text.isEmpty || !state.knownMembers.contains(_coTreasurerController.text) 
                 ? null : _coTreasurerController.text,
          decoration: InputDecoration(
            labelText: "Co-tesoureiro",
            hintText: "Selecione o co-tesoureiro",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: state.knownMembers.map((String member) {
            return DropdownMenuItem<String>(value: member, child: Text(member, style: const TextStyle(fontSize: 14)));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _coTreasurerController.text = val);
            }
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: (state.error == null && !state.isSubmitting && state.difference == 0 && state.physicalTotal > 0 && _coTreasurerController.text.isNotEmpty) ? () {
            _syncTimer?.cancel();
            context.read<ServiceClosingBloc>().add(
              InitializeClosingContextEvent(state.date ?? DateTime.now(), state.mainTreasurer, _coTreasurerController.text)
            );
            context.read<ServiceClosingBloc>().add(SubmitClosingEvent());
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A), 
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            disabledForegroundColor: const Color(0xFF9CA3AF),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: state.isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("ENVIAR FECHAMENTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                foregroundColor: const Color(0xFF1E3A8A),
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
                                backgroundColor: const Color(0xFF1E3A8A),
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
