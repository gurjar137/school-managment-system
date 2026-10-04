import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/access_models.dart';

class ParentCodesScreen extends ConsumerStatefulWidget {
  const ParentCodesScreen({super.key});

  @override
  ConsumerState<ParentCodesScreen> createState() => _ParentCodesScreenState();
}

class _ParentCodesScreenState extends ConsumerState<ParentCodesScreen> {
  final _searchController = TextEditingController();
  String _selectedClassFilter = 'All';
  String _selectedStatusFilter = 'All'; // All, Active, Revoked

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessService = ref.watch(accessServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Parent Access Codes Registry', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Metric
          BentoCard(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PTM PARENT CODE MANAGEMENT', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const Icon(Icons.qr_code_2_rounded, color: AppColors.softLavender, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Unique Student Access Keys', style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Hand unique access codes to parents during PTM for Parent App linking.', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          CustomSearchBar(
            controller: _searchController,
            hintText: 'Search by Student, Code (e.g. SC-7K4P-92MX), Adm No...',
            onChanged: (_) => setState(() {}),
            onClear: () {
              _searchController.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Statuses', _selectedStatusFilter == 'All', () => setState(() => _selectedStatusFilter = 'All')),
                _buildFilterChip('Active Codes', _selectedStatusFilter == 'Active', () => setState(() => _selectedStatusFilter = 'Active')),
                _buildFilterChip('Revoked Codes', _selectedStatusFilter == 'Revoked', () => setState(() => _selectedStatusFilter = 'Revoked')),
                const SizedBox(width: 12),
                _buildFilterChip('All Classes', _selectedClassFilter == 'All', () => setState(() => _selectedClassFilter = 'All')),
                _buildFilterChip('Class 8-A', _selectedClassFilter == '8', () => setState(() => _selectedClassFilter = '8')),
                _buildFilterChip('Class 1', _selectedClassFilter == '1', () => setState(() => _selectedClassFilter = '1')),
              ],
            ),
          ),
          const SizedBox(height: 16),

          FutureBuilder<List<ParentAccessCodeModel>>(
            future: accessService.getAllParentCodes(
              query: _searchController.text,
              className: _selectedClassFilter,
              onlyRevoked: _selectedStatusFilter == 'Revoked' ? true : null,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Retrieving Parent Access Codes...');
              }
              var codes = snapshot.data ?? [];

              if (_selectedStatusFilter == 'Active') {
                codes = codes.where((c) => c.isActive).toList();
              }

              if (codes.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'No Matching Codes',
                  message: 'No student access codes matched your search or status filter.',
                );
              }

              return Column(
                children: codes.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BentoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.studentName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                  Text('Adm No: ${item.admissionNo} • ${item.className}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                              _buildStatusBadge(item.isActive),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Display Code Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: item.isActive ? AppColors.softLavender.withOpacity(0.4) : AppColors.softCoral.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PARENT ACCESS CODE', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 9)),
                                    Text(
                                      item.isActive ? item.code : 'REVOKED - INVALID',
                                      style: AppTypography.numericHeader.copyWith(
                                        fontSize: 18,
                                        color: item.isActive ? AppColors.softLavender : AppColors.softCoral,
                                        decoration: item.isRevoked ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: AppColors.softLavender, size: 20),
                                  tooltip: 'Copy Code',
                                  onPressed: item.isActive
                                      ? () {
                                          Clipboard.setData(ClipboardData(text: item.code));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Code ${item.code} copied to clipboard!')),
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmRegenerateCode(context, item),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Regenerate'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: item.isActive ? () => _confirmRevokeAccess(context, item) : null,
                                  icon: const Icon(Icons.block_rounded, size: 16, color: AppColors.softCoral),
                                  label: const Text('Revoke', style: TextStyle(color: AppColors.softCoral)),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  void _confirmRegenerateCode(BuildContext context, ParentAccessCodeModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Regenerate Parent Access Code?', style: AppTypography.titleLarge),
          content: Text(
            'Regenerating this code will invalidate the previous code (${item.code}) for ${item.studentName}. Continue?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final newCodeRecord = await ref.read(accessServiceProvider).regenerateParentCode(item.studentId);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.mutedGreen,
                      content: Text('New code ${newCodeRecord.code} generated for ${item.studentName}!'),
                    ),
                  );
                }
              },
              child: const Text('Generate New Code'),
            ),
          ],
        );
      },
    );
  }

  void _confirmRevokeAccess(BuildContext context, ParentAccessCodeModel item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Revoke Parent Access?', style: AppTypography.titleLarge),
          content: Text(
            'Revoking access for ${item.studentName} will invalidate code ${item.code}. Student academic data remains untouched.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(accessServiceProvider).revokeParentAccess(item.studentId);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Parent access REVOKED for ${item.studentName}')),
                  );
                }
              },
              child: const Text('Revoke Access'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.mutedGreen.withOpacity(0.15) : AppColors.softCoral.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? AppColors.mutedGreen : AppColors.softCoral),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Revoked',
            style: AppTypography.bodySmall.copyWith(color: isActive ? AppColors.mutedGreen : AppColors.softCoral, fontWeight: FontWeight.w800, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
