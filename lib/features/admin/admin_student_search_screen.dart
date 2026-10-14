import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/student_model.dart';

class AdminStudentSearchScreen extends ConsumerStatefulWidget {
  const AdminStudentSearchScreen({super.key});

  @override
  ConsumerState<AdminStudentSearchScreen> createState() => _AdminStudentSearchScreenState();
}

class _AdminStudentSearchScreenState extends ConsumerState<AdminStudentSearchScreen> {
  final _searchController = TextEditingController();
  List<StudentModel> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  void _performSearch(String query) async {
    setState(() => _isLoading = true);
    final repo = ref.read(schoolRepositoryProvider);
    final results = await repo.getStudents(query: query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/students'),
        title: Text('Global Student Search', style: AppTypography.titleLarge),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search by name, admission, roll no, parent name or mobile...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.softLavender),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Count & Status Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_searchResults.length} Students Matched',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.coolGray),
                ),
                Text(
                  'Campus Global Registry',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                ),
              ],
            ),
          ),
          const Divider(),

          // Search Results List
          Expanded(
            child: _isLoading
                ? const LoadingStateWidget(message: 'Searching campus records...')
                : _searchResults.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.person_search_rounded,
                        title: 'No Matching Students',
                        message: 'No student found matching your search term.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final student = _searchResults[index];
                          return _buildSearchTile(context, student);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTile(BuildContext context, StudentModel student) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        onTap: () => context.push('/student/${student.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  imageUrl: student.avatarUrl,
                  name: student.name,
                  radius: 24,
                  borderColor: AppColors.softLavender,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            student.name,
                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.midnightNavy,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Class ${student.fullClassCode}',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.pureWhite, fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Roll No: ${student.rollNumber} • Adm No: ${student.admissionNumber}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.family_restroom_rounded, size: 16, color: AppColors.softLavender),
                    const SizedBox(width: 6),
                    Text(
                      'Father: ${student.fatherName}',
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  student.fatherMobile,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
