import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/user_model.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'All';
  int _refreshKey = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _refreshKey++);
  }

  Future<void> _showAddBookDialog() async {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Catalog New Book', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Book Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter book title' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: authorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Author *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter author name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: isbnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ISBN / Accession No.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final user = ref.read(authProvider);
                        final libService = ref.read(libraryServiceProvider);
                        await libService.addBook(
                          schoolId: user?.schoolId,
                          title: titleCtrl.text.trim(),
                          author: authorCtrl.text.trim(),
                          isbn: isbnCtrl.text.trim().isEmpty ? 'ISBN-${DateTime.now().millisecondsSinceEpoch}' : isbnCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.mutedGreen,
                              content: Text('Book cataloged successfully!'),
                            ),
                          );
                          _reload();
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.softCoral,
                              content: Text('Failed to add book: $e'),
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Catalog Book', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(schoolRepositoryProvider);
    final user = ref.watch(authProvider);
    final canManageBooks = (user?.role?.isAdministrator ?? false) || user?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Campus Library', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh library',
            onPressed: _reload,
          ),
          if (canManageBooks)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Catalog Book',
              onPressed: _showAddBookDialog,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: Column(
          children: [
            // Search and Status Filters
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.pureWhite,
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search books by title, author, or ISBN...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.coolGray),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.warmOffWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Available', 'Issued', 'Overdue'].map((status) {
                        final isSelected = _selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedStatus = status),
                            selectedColor: AppColors.softLavender.withOpacity(0.2),
                            checkmarkColor: AppColors.softLavender,
                            labelStyle: AppTypography.bodySmall.copyWith(
                              color: isSelected ? AppColors.softLavender : AppColors.coolGrayDark,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),

            // Books List
            Expanded(
              child: FutureBuilder<List<LibraryBookModel>>(
                key: ValueKey(_refreshKey),
                future: repo.getLibraryBooks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingStateWidget(message: 'Cataloging books...');
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.softCoral),
                            const SizedBox(height: 12),
                            Text('Unable to load library records', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('${snapshot.error}', textAlign: TextAlign.center, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry Connection'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allBooks = snapshot.data ?? [];

                  // Apply client-side filters
                  final query = _searchCtrl.text.trim().toLowerCase();
                  final filteredBooks = allBooks.where((b) {
                    final matchesStatus = _selectedStatus == 'All' ||
                        b.status.name.toLowerCase() == _selectedStatus.toLowerCase();
                    final matchesQuery = query.isEmpty ||
                        b.title.toLowerCase().contains(query) ||
                        b.author.toLowerCase().contains(query) ||
                        b.isbn.toLowerCase().contains(query);
                    return matchesStatus && matchesQuery;
                  }).toList();

                  if (filteredBooks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.softLavender.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.menu_book_rounded, size: 48, color: AppColors.softLavender),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              allBooks.isEmpty ? 'Campus Library is Empty' : 'No Matching Books Found',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allBooks.isEmpty
                                  ? 'No books have been cataloged in this school yet.'
                                  : 'Try adjusting your search query or filter chips.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                            ),
                            if (canManageBooks) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.softLavender,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _showAddBookDialog,
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text('Catalog First Book'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final b = filteredBooks[index];
                      Color badgeBg = AppColors.greenLight;
                      Color badgeText = AppColors.greenDark;
                      if (b.status == BookStatus.overdue) {
                        badgeBg = AppColors.coralLight;
                        badgeText = AppColors.coralDark;
                      } else if (b.status == BookStatus.issued) {
                        badgeBg = AppColors.amberLight;
                        badgeText = AppColors.amberDark;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BentoCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.softLavender.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.menu_book_rounded, color: AppColors.softLavender, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('Author: ${b.author}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                    if (b.isbn.isNotEmpty)
                                      Text('ISBN: ${b.isbn}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                                    if (b.issuedToStudent != null && b.issuedToStudent!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Issued to: ${b.issuedToStudent}', style: AppTypography.bodySmall.copyWith(color: AppColors.amberDark, fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  b.status.name.toUpperCase(),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: badgeText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
