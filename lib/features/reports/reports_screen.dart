import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Executive Analytics & Reports', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly School Health Score', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('96.2 / 100', style: AppTypography.numericHeader.copyWith(fontSize: 28, color: AppColors.mutedGreen)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                      child: Text('EXCELLENT', style: AppTypography.labelSmall.copyWith(color: AppColors.greenDark, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Available Operational Reports'),
          const SizedBox(height: 8),

          _buildReportTile('Monthly Attendance Summary', 'Detailed daily breakdown of staff and student presence.', Icons.fact_check_outlined),
          _buildReportTile('Academic Performance Matrix', 'Term exam scores, subject grade averages, and pass ratios.', Icons.bar_chart_rounded),
          _buildReportTile('Homework & Assignment Velocity', 'Submission rates across classes 6 to 10.', Icons.assignment_outlined),
          _buildReportTile('Fee Collection Audit', 'Paid vs outstanding revenue balances by class.', Icons.payments_outlined),
        ],
      ),
    );
  }

  Widget _buildReportTile(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.midnightNavy.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.midnightNavy, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                  Text(desc, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                ],
              ),
            ),
            const Icon(Icons.download_rounded, color: AppColors.softLavender),
          ],
        ),
      ),
    );
  }
}
