import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/school_management_models.dart';

class AdminGlobalSearchScreen extends ConsumerStatefulWidget {
  const AdminGlobalSearchScreen({super.key});

  @override
  ConsumerState<AdminGlobalSearchScreen> createState() => _AdminGlobalSearchScreenState();
}

class _AdminGlobalSearchScreenState extends ConsumerState<AdminGlobalSearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  CategorizedSearchResult? _searchResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final res = await ref.read(schoolManagementServiceProvider).performCategorizedSearch(query);

    if (mounted) {
      setState(() {
        _searchResult = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Categorized Global Search', style: AppTypography.titleLarge),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search student, roll no, parent mobile, teacher emp ID...',
              onChanged: _performSearch,
              onClear: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
          ),

          if (_searchResult != null)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.softLavender,
              unselectedLabelColor: AppColors.coolGray,
              indicatorColor: AppColors.softLavender,
              tabs: [
                Tab(text: 'Students (${_searchResult!.students.length})'),
                Tab(text: 'Teachers (${_searchResult!.teachers.length})'),
                Tab(text: 'Receipts (${_searchResult!.receipts.length})'),
                const Tab(text: 'Results (0)'),
              ],
            ),

          Expanded(
            child: _isLoading
                ? const LoadingStateWidget(message: 'Searching campus records...')
                : _searchResult == null
                    ? const EmptyStateWidget(
                        icon: Icons.search_rounded,
                        title: 'Categorized Campus Search',
                        message: 'Type a student name, admission number, roll no, parent phone, or teacher ID to search across all modules.',
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStudentsList(_searchResult!.students),
                          _buildTeachersList(_searchResult!.teachers),
                          _buildReceiptsList(_searchResult!.receipts),
                          const EmptyStateWidget(icon: Icons.quiz_outlined, title: 'No Matching Results', message: 'No published examination results matched search.'),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(List<dynamic> students) {
    if (students.isEmpty) {
      return const EmptyStateWidget(icon: Icons.person_off_outlined, title: 'No Students Found', message: 'No student records matched search query.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, idx) {
        final s = students[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BentoCard(
            onTap: () => context.push('/student/${s.id}'),
            child: Row(
              children: [
                AppAvatar(imageUrl: s.avatarUrl, name: s.name, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                      Text('Class ${s.fullClassCode} • Adm: ${s.admissionNumber} • Roll: ${s.rollNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.coolGray),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeachersList(List<dynamic> teachers) {
    if (teachers.isEmpty) {
      return const EmptyStateWidget(icon: Icons.badge_outlined, title: 'No Teachers Found', message: 'No faculty records matched search query.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teachers.length,
      itemBuilder: (context, idx) {
        final t = teachers[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BentoCard(
            child: Row(
              children: [
                AppAvatar(imageUrl: t.avatarUrl, name: t.name, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                      Text('${t.designation} • ${t.assignedClass} • ${t.subjects.join(", ")}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptsList(List<dynamic> receipts) {
    if (receipts.isEmpty) {
      return const EmptyStateWidget(icon: Icons.receipt_long_outlined, title: 'No Receipts Found', message: 'No fee receipts matched search query.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: receipts.length,
      itemBuilder: (context, idx) {
        final r = receipts[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.receiptNumber, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.softLavender)),
                    Text('₹${r.amountPaid.toStringAsFixed(0)}', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.mutedGreen)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Student: ${r.studentName} • ${r.className} • ${r.paymentMethod}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
              ],
            ),
          ),
        );
      },
    );
  }
}
