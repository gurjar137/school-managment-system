import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/result_models.dart';

class ClassAnalyticsScreen extends ConsumerStatefulWidget {
  final String examId;

  const ClassAnalyticsScreen({super.key, required this.examId});

  @override
  ConsumerState<ClassAnalyticsScreen> createState() => _ClassAnalyticsScreenState();
}

class _ClassAnalyticsScreenState extends ConsumerState<ClassAnalyticsScreen> {
  bool _enableRanking = true;

  @override
  Widget build(BuildContext context) {
    final resultService = ref.watch(resultServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Class Performance Analytics', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: Icon(_enableRanking ? Icons.emoji_events_rounded : Icons.emoji_events_outlined, color: AppColors.warmAmber),
            tooltip: 'Toggle Leaderboard Ranking',
            onPressed: () => setState(() => _enableRanking = !_enableRanking),
          ),
        ],
      ),
      body: FutureBuilder<ClassResultSummary>(
        future: resultService.getClassResultSummary(widget.examId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Computing class performance metrics...');
          }
          final summary = snapshot.data;
          if (summary == null) {
            return const EmptyStateWidget(icon: Icons.bar_chart_outlined, title: 'No Data Available', message: 'No evaluation records available for analytics.');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Header Banner
              BentoCard(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${summary.examTitle.toUpperCase()} • CLASS ${summary.className}', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const SizedBox(height: 6),
                    Text('${summary.classAverage.toStringAsFixed(1)}%', style: AppTypography.numericHeader.copyWith(color: AppColors.pureWhite, fontSize: 32)),
                    Text('Overall Class Average Score', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Highest: ${summary.highestPercentage.toStringAsFixed(1)}%', style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w700)),
                        Text('Lowest: ${summary.lowestPercentage.toStringAsFixed(1)}%', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pass / Fail Ratio Row
              Row(
                children: [
                  Expanded(
                    child: BentoCard(
                      child: Column(
                        children: [
                          Text('${summary.passedCount}', style: AppTypography.numericHeader.copyWith(fontSize: 26, color: AppColors.mutedGreen)),
                          Text('Passed Students', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BentoCard(
                      child: Column(
                        children: [
                          Text('${summary.failedCount}', style: AppTypography.numericHeader.copyWith(fontSize: 26, color: AppColors.softCoral)),
                          Text('Needs Improvement', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text('SUBJECT-WISE CLASS AVERAGES', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              BentoCard(
                child: Column(
                  children: summary.subjectAverages.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                              Text('${e.value.toStringAsFixed(1)}%', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: e.value / 100.0,
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.softLavender),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              if (_enableRanking) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CLASS LEADERBOARD & RANKINGS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.warmAmber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text('RANKING ACTIVE', style: AppTypography.bodySmall.copyWith(color: AppColors.warmAmber, fontWeight: FontWeight.w800, fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                FutureBuilder<List<StudentResultModel>>(
                  future: resultService.getStudentResultsForExam(widget.examId),
                  builder: (context, resSnapshot) {
                    if (!resSnapshot.hasData) return const SizedBox.shrink();
                    final sortedList = List<StudentResultModel>.from(resSnapshot.data!);
                    sortedList.sort((a, b) => b.percentage.compareTo(a.percentage));

                    return Column(
                      children: sortedList.asMap().entries.map((entry) {
                        final rank = entry.key + 1;
                        final s = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BentoCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: rank == 1
                                        ? AppColors.warmAmber
                                        : rank == 2
                                            ? AppColors.coolGray
                                            : rank == 3
                                                ? AppColors.softCoral
                                                : AppColors.surfaceLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#$rank',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: rank <= 3 ? AppColors.pureWhite : AppColors.coolGray,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.studentName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                      Text('Roll No: ${s.rollNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${s.percentage.toStringAsFixed(1)}% (${s.overallGrade})',
                                  style: AppTypography.titleSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
