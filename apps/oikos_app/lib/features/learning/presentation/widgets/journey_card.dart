import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/journey.dart';
import 'progress_ring.dart';

class JourneyCard extends StatelessWidget {
  final Journey journey;
  final double progressPercentage;
  final int completedLessonsCount;
  final int totalLessonsCount;
  final String? activeChapterTitle;
  final VoidCallback onTap;

  const JourneyCard({
    super.key,
    required this.journey,
    required this.progressPercentage,
    this.completedLessonsCount = 0,
    this.totalLessonsCount = 0,
    this.activeChapterTitle,
    required this.onTap,
  });

  Color _parseColor(String hex) {
    var hexColor = hex.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse('0x$hexColor'));
  }

  @override
  Widget build(BuildContext context) {
    final journeyColor = _parseColor(journey.colorHex);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: journeyColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: journeyColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      // Icon can be loaded from assets or use a placeholder
                      child: Icon(Icons.menu_book_rounded, color: journeyColor, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          journey.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          journey.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalLessonsCount > 0
                            ? '$completedLessonsCount de $totalLessonsCount lições concluídas'
                            : 'Progresso da Trilha',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progressPercentage >= 1.0
                            ? 'Trilha Completa ⭐'
                            : (activeChapterTitle != null && activeChapterTitle!.isNotEmpty
                                ? activeChapterTitle!
                                : (progressPercentage > 0 ? 'Em andamento' : 'Pronto para começar')),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: journeyColor,
                        ),
                      ),
                    ],
                  ),
                  ProgressRing(
                    percentage: progressPercentage,
                    activeColor: journeyColor,
                    size: 52,
                    strokeWidth: 5,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
