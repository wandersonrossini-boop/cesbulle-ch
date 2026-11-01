import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/journey.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/lesson.dart';
import '../providers/journey_provider.dart';
import '../providers/current_journey_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/journey_card.dart';
import 'chapter_page.dart';
import 'lesson_page.dart';

class JourneyPage extends ConsumerWidget {
  const JourneyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeysAsync = ref.watch(journeyProvider);
    final currentState = ref.watch(currentJourneyProvider);
    final userId = currentState.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Jornadas de Aprendizagem',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: journeysAsync.when(
        data: (journeys) {
          if (journeys.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma jornada disponível no momento.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return _JourneyListView(
            journeys: journeys,
            userId: userId,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Erro ao carregar jornadas: $err')),
      ),
    );
  }
}

class _JourneyListView extends ConsumerWidget {
  final List<Journey> journeys;
  final String userId;

  const _JourneyListView({
    required this.journeys,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Coleta dados de progresso de todas as jornadas
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: journeys.length + 1, // +1 para o Hero Card de Sugestão/Foco
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildDailyHeroCard(context, ref);
        }

        final journey = journeys[index - 1];
        return _JourneyCardItem(journey: journey, userId: userId);
      },
    );
  }

  Widget _buildDailyHeroCard(BuildContext context, WidgetRef ref) {
    // Escolhe a primeira jornada ou a primeira com lições pendentes como foco diário
    final firstJourney = journeys.isNotEmpty ? journeys.first : null;
    if (firstJourney == null || firstJourney.chapters.isEmpty) return const SizedBox.shrink();

    final firstChapter = firstJourney.chapters.first;
    final firstLesson = firstChapter.lessons.isNotEmpty ? firstChapter.lessons.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.amberAccent, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'META DE HOJE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                '~7 min',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            firstLesson?.title ?? 'Exploração Suíça',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            firstLesson?.description ?? 'Pratique no contexto diário da Suíça Romanda.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1E3A8A), size: 26),
              label: const Text(
                'CONTINUAR LIÇÃO',
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                if (firstLesson != null) {
                  ref.read(currentJourneyProvider.notifier).setJourney(firstJourney, userId: userId);
                  ref.read(currentJourneyProvider.notifier).setChapter(firstChapter);
                  ref.read(currentJourneyProvider.notifier).setLesson(firstLesson);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LessonPage()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCardItem extends ConsumerWidget {
  final Journey journey;
  final String userId;

  const _JourneyCardItem({
    required this.journey,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userJourneyProgressProvider((userId: userId, journeyId: journey.id)));

    return progressAsync.when(
      data: (userProgress) {
        // Calcula progresso real
        int totalLessons = 0;
        for (final ch in journey.chapters) {
          totalLessons += ch.lessons.length;
        }

        final completedCount = userProgress.completedLessonIds.length;
        final progressRatio = totalLessons > 0 ? (completedCount / totalLessons).clamp(0.0, 1.0) : 0.0;

        // Identifica o capítulo atual ativo
        String? activeChapterTitle;
        for (final ch in journey.chapters) {
          final hasUnfinished = ch.lessons.any((l) => !userProgress.completedLessonIds.contains(l.id));
          if (hasUnfinished) {
            activeChapterTitle = ch.title;
            break;
          }
        }

        return _buildCard(context, ref, progressRatio, completedCount, totalLessons, activeChapterTitle);
      },
      loading: () => _buildCard(context, ref, 0.0, 0, 0, null),
      error: (_, __) => _buildCard(context, ref, 0.0, 0, 0, null),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    double progressRatio,
    int completedCount,
    int totalLessons,
    String? activeChapterTitle,
  ) {
    return Hero(
      tag: 'journey_${journey.id}',
      child: Material(
        color: Colors.transparent,
        child: JourneyCard(
          journey: journey,
          progressPercentage: progressRatio,
          completedLessonsCount: completedCount,
          totalLessonsCount: totalLessons,
          activeChapterTitle: activeChapterTitle,
          onTap: () {
            ref.read(currentJourneyProvider.notifier).setJourney(journey, userId: userId);
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const ChapterPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
