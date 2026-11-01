import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../presentation/providers/family_members_provider.dart';
import '../../../presentation/providers/di_providers.dart';
import '../../../domain/entities/age_experience_mode.dart';
import '../../../domain/entities/family_member.dart';
import '../../domain/entities/home_scene_state.dart';
import '../widgets/family_ranking_panel.dart';
import '../providers/xp_provider.dart';
import '../../domain/xp_repository.dart';
import '../../../../features/learning/domain/adaptive_study_tool.dart';
import '../../../../features/brain/presentation/providers/brain_provider.dart';
import '../../../../features/brain/presentation/providers/trajectory_provider.dart';
import '../../../../features/brain/domain/entities/learning_decision.dart';
import '../../../../features/brain/domain/entities/learning_event.dart';
import '../../../../features/avatar/presentation/avatar_renderer.dart';
import '../../../../features/avatar/domain/avatar.dart';
import '../../../../features/avatar/domain/avatar_expression.dart';
import '../../../../features/avatar/presentation/pages/avatar_editor_page.dart';
import '../../../../features/companion/domain/lumo_variant.dart';
import '../../../../features/companion/presentation/widgets/lumo_renderer.dart';
import 'dart:convert';
import 'package:hive/hive.dart';

class LivingScenePage extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const LivingScenePage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<LivingScenePage> createState() => _LivingScenePageState();
}

class _LivingScenePageState extends ConsumerState<LivingScenePage> {
  HomeSceneState _currentState = HomeSceneState.firstVisit;
  int? _lastXpGained;
  bool _isLausanneCompleted = false;

  @override
  void initState() {
    super.initState();
    _updateMissionStatus();
  }

  void _updateMissionStatus() {
    try {
      if (Hive.isBoxOpen('missionProgressBox')) {
        final box = Hive.box<Map>('missionProgressBox');
        _isLausanneCompleted = box.get('ch_numbers_nonante_001') != null;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mensagens contextuais do Lumo por XP
  // ──────────────────────────────────────────────────────────────────────────
  String _lumoMessage(int xp, int level, int? lastGained, LearningDecision? decision) {
    if (lastGained != null) {
      final toNext = XpRepository.xpForNextLevel(xp);
      if (toNext <= 20) return 'Faltam só $toNext XP para o nível ${level + 1}! 🚀';
      return '+$lastGained XP! Continue assim, ${widget.userName}! ⭐';
    }
    if (_currentState == HomeSceneState.suggestingActivity && decision != null) {
      return decision.motivationLine;
    }
    if (_currentState == HomeSceneState.celebrating) {
      return 'Que escolha incrível! Vamos lá! 🚀';
    }
    if (decision != null && xp > 0) {
      return decision.motivationLine;
    }
    // Mensagem inicial e contextual
    if (xp == 0) {
      if (decision != null && decision.topic.isNotEmpty) {
        return 'Olá ${widget.userName}! Vamos explorar ${decision.topic}?';
      }
      return 'Olá ${widget.userName}! Que tal começar sua primeira missão suíça?';
    }
    if (level == 1) return 'Bom começo! Mais ${XpRepository.xpForNextLevel(xp)} XP para o nível 2!';
    if (level >= 5) return 'Uau! Nível $level! Você é incrível, ${widget.userName}! 🌟';
    return 'Nível $level desbloqueado! O que quer aprender hoje?';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Navegação Adaptativa de Aprendizado
  // ──────────────────────────────────────────────────────────────────────────
  void _handleObjectTap(String objectId, AgeExperienceMode mode, LearningDecision decision, SceneObjectSpec spec) async {
    setState(() => _currentState = HomeSceneState.celebrating);

    // Oikos Philosophy: Adapt the experience to the user's cognitive style.
    final bool isAdult = (mode == AgeExperienceMode.adult || mode == AgeExperienceMode.senior || mode == AgeExperienceMode.youngMentor);

    if (isAdult) {
      // Adultos: Preferem uma visão direta e clara do seu currículo.
      await Navigator.pushNamed(context, '/learning');
      if (!mounted) return;
      setState(() {
        _updateMissionStatus();
      });
    } else {
      // Crianças/Exploradores: Aprendem explorando o ambiente. 
      // Abre a ferramenta adaptativa direto no cenário (imersão).
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: AdaptiveStudyTool.fromDecision(
            decision: decision,
            toolIdOverride: spec.toolId,
            userId: widget.userId,
            experienceMode: mode,
            onEvent: (event) async {
              try {
                await ref.read(trajectoryRepositoryProvider).saveEvent(event);
              } catch (e) {
                debugPrint('Horizon Trajectory saveEvent error: $e');
              }
            },
            onSessionFinished: (result) async {
              try {
                final sessionEvent = result.userId == widget.userId
                    ? result
                    : SessionFinished(
                        eventId: result.eventId,
                        sessionId: result.sessionId,
                        userId: widget.userId,
                        timestamp: result.timestamp,
                        toolId: result.toolId,
                        topic: result.topic,
                        difficulty: result.difficulty,
                        totalDurationSeconds: result.totalDurationSeconds,
                        accuracy: result.accuracy,
                        errorCount: result.errorCount,
                      );
                await ref.read(trajectoryRepositoryProvider).saveEvent(sessionEvent);
                ref.invalidate(learningDecisionProvider(widget.userId));

                final progressBox = await Hive.openBox<Map>('missionProgressBox');
                await progressBox.put('ch_numbers_nonante_001', {
                  'completedAt': DateTime.now().toIso8601String(),
                  'accuracy': result.accuracy,
                  'toolId': result.toolId,
                });
              } catch (e) {
                debugPrint('Horizon Trajectory saveSession error: $e');
              }
              
              Navigator.pop(context);
              await ref.read(xpProvider(widget.userId).notifier).addXp(20);
              if (mounted) {
                setState(() {
                  _lastXpGained = 20;
                  _currentState = HomeSceneState.celebrating;
                });
                Future.delayed(const Duration(milliseconds: 2500), () {
                  if (mounted) setState(() => _lastXpGained = null);
                });
              }
            },
          ),
        ),
      );
    }
  }


  // ──────────────────────────────────────────────────────────────────────────
  // Menu do Livro e Progresso
  // ──────────────────────────────────────────────────────────────────────────
  void _showBookProgressMenu(BuildContext context, List<FamilyMember> members) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FutureBuilder<Box<Map>>(
        future: Hive.openBox<Map>('missionProgressBox'),
        builder: (context, snapshot) {
          final box = snapshot.data;
          final bool isLausanneCompleted = box?.get('ch_numbers_nonante_001') != null;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(icon: Icon(Icons.map_outlined), text: 'Progresso'),
                      Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Ranking'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Aba 1: Progresso Contextual Reativo
                        ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const Text(
                              'Progresso por Cenários',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.school, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/learning');
                                },
                                label: const Text(
                                  'Ver Todas as 4 Jornadas e Capítulos',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildScenarioProgressItem(
                              '🛒', 
                              'Mercado (Français)', 
                              isLausanneCompleted ? 1.0 : 0.0, 
                              const Color(0xFF10B981),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/learning');
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildScenarioProgressItem(
                              '🏫', 
                              'Escola (Português)', 
                              0.0, 
                              Colors.blue,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/learning');
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildScenarioProgressItem(
                              '🏥', 
                              'Médico (Matemática)', 
                              0.0, 
                              Colors.orange,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/learning');
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildScenarioProgressItem(
                              '✈️', 
                              'Aeroporto (Inglês)', 
                              0.00, 
                              Colors.grey,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/learning');
                              },
                            ),
                            const Divider(height: 48),
                            const Text(
                              'Missões Concluídas',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (isLausanneCompleted)
                              _buildCompletedMissionItem('Entender o preço no caixa (Lausanne)'),
                            if (!isLausanneCompleted)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Nenhuma missão concluída nesta jornada. Explore a cidade para começar!',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                        // Aba 2: Ranking Familiar
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: FamilyRankingPanel(
                            members: members,
                            currentUserId: widget.userId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildScenarioProgressItem(String emoji, String title, double progress, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedMissionItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Menu do Avatar e Configurações
  // ──────────────────────────────────────────────────────────────────────────
  void _showAvatarMenu(BuildContext context, FamilyMember currentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Perfil de ${currentUser.name}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildMenuButton(
              icon: Icons.palette_outlined,
              title: 'Montar Meu Avatar',
              subtitle: 'Altere o cabelo, roupas e cores do seu personagem',
              onTap: () {
                Navigator.pop(context);
                _openAvatarEditor(currentUser);
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              icon: Icons.emoji_events_outlined,
              title: 'Ver Minhas Conquistas',
              subtitle: 'Confira seus emblemas e progresso na jornada',
              onTap: () {
                Navigator.pop(context);
                _showAchievementsDialog(currentUser);
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              icon: Icons.people_outline,
              title: 'Trocar de Perfil',
              subtitle: 'Retornar para a tela de seleção de usuários',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _openAvatarEditor(FamilyMember member) {
    // Usa helper centralizado (suporta JSON puro e URL-encoded)
    final OikosAvatar? initialAvatar = OikosAvatar.tryFromAvatarAsset(member.avatarAsset);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: AvatarEditorPage(
          avatarId: member.id,
          initialAvatar: initialAvatar,
          onSave: (avatar) async {
            final updatedMember = member.copyWith(
              avatarAsset: jsonEncode(avatar.toJson()),
            );
            await ref.read(familyRepositoryProvider).saveFamilyMember(updatedMember);
            ref.invalidate(familyMembersProvider);
          },
        ),
      ),
    );
  }

  void _showAchievementsDialog(FamilyMember member) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆 Conquistas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Confira os emblemas obtidos por ${member.name}:',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              _buildAchievementItem('🎨', 'Criador de Identidades', 'Personalizou o visual do seu avatar.'),
              const SizedBox(height: 12),
              _buildAchievementItem('🐾', 'Melhor Amigo do Lumo', 'Interagiu com o Lumo na sala principal.'),
              const SizedBox(height: 12),
              _buildAchievementItem('🚀', 'Pioneiro Oikos', 'Iniciou a jornada no ecossistema adaptativo.'),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementItem(String emoji, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Avatar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildUserAvatar(String? assetPath, String emojiFallback, {AvatarExpressionType expression = AvatarExpressionType.neutral}) {
    // Usa helper centralizado (suporta JSON puro e URL-encoded %7B)
    final parsed = OikosAvatar.tryFromAvatarAsset(assetPath);
    final OikosAvatar avatar = (parsed ?? OikosAvatar.defaultAvatar('user', scale: 1.0)).copyWithExpression(expression);

    return Container(
      width: 150,
      height: 250,
      alignment: Alignment.bottomCenter,
      child: OikosAvatarRenderer(avatar: avatar, size: 250),
    );
  }

  Widget _buildSpeechBubble(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        message,
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ).animate(key: ValueKey(message))
     .fadeIn(duration: 400.ms)
     .scaleXY(begin: 0.85, end: 1.0, curve: Curves.easeOutBack);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);
    final xpState = ref.watch(xpProvider(widget.userId));
    final decisionAsync = ref.watch(learningDecisionProvider(widget.userId));

    if (xpState.justLeveledUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLevelUpDialog(xpState.level);
        ref.read(xpProvider(widget.userId).notifier).clearLevelUpFlag();
      });
    }

    return Scaffold(
      body: membersAsync.when(
        data: (members) {
          final currentUser = members.firstWhere((m) => m.id == widget.userId, orElse: () => members.first);
          final bool isToddler = currentUser.experienceMode == AgeExperienceMode.earlyChildhood;

          return decisionAsync.when(
            data: (decision) {
              return Stack(
                children: [
                  // 1. Cenário e Chão (Fundo)
                  Column(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFF8F0), Color(0xFFFFEEDB)],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFE5D5C5), // O Chão
                          ),
                          alignment: Alignment.topCenter,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black.withOpacity(0.05), Colors.transparent],
                              )
                            ),
                          ),
                        ),
                      )
                    ],
                  ),

                  // 2. XP HUD (Visual para toddlers, com estrelas)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: SafeArea(
                      bottom: false, 
                      child: isToddler 
                          ? _buildToddlerHud(xpState) 
                          : _buildXpHud(xpState, currentUser.name),
                    ),
                  ),

                  // 3. Personagens ancorados ao chão com Card de Missão Pedagógica
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildUnityOrFallbackScene(currentUser, members, decision, xpState, isToddler),
                    ),
                  ),

                  if (_lastXpGained != null)
                    Positioned(top: 150, left: 0, right: 0, child: _buildXpToast(_lastXpGained!)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Erro: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erro ao carregar familia: $e')),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Toddler HUD (Zero Texto, apenas estrelas/frutinhas)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildToddlerHud(XpState xp) {
    final int starCount = (xp.xp / 20).floor().clamp(1, 5);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(starCount, (index) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '⭐',
              style: TextStyle(fontSize: 28),
            ),
          )),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Converte HomeSceneState → LumoVariant
  // ──────────────────────────────────────────────────────────────────────────
  LumoVariant _lumoVariant() {
    switch (_currentState) {
      case HomeSceneState.celebrating:
        return LumoVariant.celebrating;
      case HomeSceneState.suggestingActivity:
        return LumoVariant.listening;
      default:
        return LumoVariant.idle;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Cenário Principal: Lumo + Avatares da Família + Ação Pedagógica Hero
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildUnityOrFallbackScene(
    FamilyMember currentUser,
    List<FamilyMember> members,
    LearningDecision decision,
    XpState xpState,
    bool isToddler,
  ) {
    final spec = decision.sceneObjects.isNotEmpty ? decision.sceneObjects.first : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Linha dos Personagens e Livro (Parte superior do chão)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar do usuário atual à esquerda
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAvatarMenu(context, currentUser),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: _buildUserAvatar(
                      currentUser.avatarAsset, 
                      currentUser.emoji,
                      expression: _currentState == HomeSceneState.celebrating 
                          ? AvatarExpressionType.happy 
                          : AvatarExpressionType.neutral,
                    ),
                  ),
                ),
              ),
            ),
            // Livro com indicador claro de progresso
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showBookProgressMenu(context, members),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _isLausanneCompleted 
                                    ? Colors.black.withOpacity(0.08)
                                    : AppColors.primary.withOpacity(0.35),
                                blurRadius: _isLausanneCompleted ? 12 : 18,
                                spreadRadius: _isLausanneCompleted ? 0 : 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: _isLausanneCompleted ? Colors.green.shade400 : AppColors.primary,
                              width: 2.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '📖',
                              style: TextStyle(fontSize: 38),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _isLausanneCompleted ? 'Revisar' : 'Jornadas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isLausanneCompleted ? Colors.green.shade700 : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Lumo no centro — mascote pedagógico
            Flexible(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balão de fala do Lumo
                  if (!isToddler) ...[
                    _buildSpeechBubble(_lumoMessage(xpState.xp, xpState.level, _lastXpGained, decision)),
                    const SizedBox(height: 8),
                  ],
                  // Lumo animado
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (spec != null) {
                          _handleObjectTap(spec.id, currentUser.experienceMode, decision, spec);
                        } else {
                          final greeting = ref.read(lumoServiceProvider).getGreeting();
                          setState(() => _currentState = HomeSceneState.suggestingActivity);
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Row(children: [
                                Text('Lumo ', style: TextStyle(fontSize: 24)),
                              ]),
                              content: Text(greeting),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Ok'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: LumoRenderer(
                        variant: _lumoVariant(),
                        size: 148,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Hero Card de Ação Principal (Pedagógica)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      decision.topic.isNotEmpty ? decision.topic.toUpperCase() : 'MISSÃO RECOMENDADA',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '✦ +20 XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                decision.actionLabel.isNotEmpty ? decision.actionLabel : 'Explorar Desafio do Dia',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      label: const Text(
                        'COMEÇAR MISSÃO ▶',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (spec != null) {
                          _handleObjectTap(spec.id, currentUser.experienceMode, decision, spec);
                        } else {
                          Navigator.pushNamed(context, '/learning');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Explorar Jornadas',
                    icon: const Icon(Icons.map_outlined, color: AppColors.primary, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/learning'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // XP HUD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildXpHud(XpState xp, String memberName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar letra
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Barra de XP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      memberName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    MissionStatusLabel(isCompleted: _isLausanneCompleted),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: xp.progress),
                    duration: 600.ms,
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppColors.achievementOrange.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(AppColors.achievementOrange),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Toast de XP
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildXpToast(int xp) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.achievementOrange,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: AppColors.achievementOrange.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          '+$xp XP ✦',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .moveY(begin: 20, end: -30, duration: 1000.ms, curve: Curves.easeOut)
        .then(delay: 300.ms)
        .fadeOut(duration: 400.ms);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Dialog de Level Up
  // ──────────────────────────────────────────────────────────────────────────
  void _showLevelUpDialog(int newLevel) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(0xFFFFFBF0),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64))
                  .animate()
                  .scaleXY(begin: 0.5, end: 1.0, duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                'Nível $newLevel!',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.achievementOrange,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Você subiu de nível!\nContinue aprendendo para desbloquear novas conquistas.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.achievementOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Incrível! 🚀',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).scaleXY(begin: 0.8),
            ],
          ),
        ),
      ),
    );
  }
}

class MissionStatusLabel extends StatelessWidget {
  final bool isCompleted;
  const MissionStatusLabel({super.key, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Text(
      isCompleted ? '1 missão concluída' : '1 missão disponível',
      style: const TextStyle(
        fontSize: 14,
        color: Colors.grey, // Cinza
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
