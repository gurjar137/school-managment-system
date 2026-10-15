import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/user_model.dart';

class AcademicYearsScreen extends ConsumerStatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  ConsumerState<AcademicYearsScreen> createState() => _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends ConsumerState<AcademicYearsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AcademicYearModel> _years = [];
  AcademicYearModel? _currentYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAcademicYears());
  }

  Future<void> _loadAcademicYears() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profile = ref.read(authProvider);
    final schoolId = profile?.schoolId?.trim() ?? '';

    if (schoolId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated school context found. Please log in again.';
      });
      return;
    }

    try {
      final service = ref.read(academicYearServiceProvider);
      final list = await service.fetchAcademicYears(schoolId);
      final current = AcademicYearOption.resolveCurrent(list);

      if (mounted) {
        setState(() {
          _years = list;
          _currentYear = current;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AcademicYearDialog(
        title: 'Create Academic Year',
        submitLabel: 'Create Year',
        existingYears: _years,
        onSubmit: (name, start, end, status) async {
          final profile = ref.read(authProvider);
          final schoolId = profile?.schoolId?.trim() ?? '';
          final service = ref.read(academicYearServiceProvider);

          await service.createAcademicYear(
            schoolId: schoolId,
            name: name,
            startDate: start,
            endDate: end,
            status: status,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.mutedGreen,
                content: Text('Academic Year "$name" created successfully!'),
              ),
            );
            _loadAcademicYears();
          }
        },
      ),
    );
  }

  void _showEditDialog(AcademicYearModel year) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AcademicYearDialog(
        title: 'Edit Academic Year',
        submitLabel: 'Save Changes',
        existingYears: _years,
        initialModel: year,
        onSubmit: (name, start, end, status) async {
          final profile = ref.read(authProvider);
          final schoolId = profile?.schoolId?.trim() ?? '';
          final service = ref.read(academicYearServiceProvider);

          await service.updateAcademicYear(
            id: year.id,
            schoolId: schoolId,
            name: name,
            startDate: start,
            endDate: end,
            status: status,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.mutedGreen,
                content: Text('Academic Year "$name" updated successfully!'),
              ),
            );
            _loadAcademicYears();
          }
        },
      ),
    );
  }

  Future<void> _toggleStatus(AcademicYearModel year) async {
    final newStatus = year.status == AccountStatus.active ? AccountStatus.inactive : AccountStatus.active;
    final profile = ref.read(authProvider);
    final schoolId = profile?.schoolId?.trim() ?? '';

    try {
      final service = ref.read(academicYearServiceProvider);
      await service.toggleStatus(id: year.id, schoolId: schoolId, newStatus: newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.softLavender,
            content: Text(
              'Academic Year "${year.name}" is now ${newStatus == AccountStatus.active ? 'ACTIVE' : 'INACTIVE'}',
            ),
          ),
        );
        _loadAcademicYears();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.softCoral, content: Text('Failed to change status: $e')),
        );
      }
    }
  }

  Future<void> _makeCurrentSession(AcademicYearModel year) async {
    final profile = ref.read(authProvider);
    final schoolId = profile?.schoolId?.trim() ?? '';

    try {
      final service = ref.read(academicYearServiceProvider);
      await service.setCurrentAcademicYear(id: year.id, schoolId: schoolId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.mutedGreen,
            content: Text('Academic Year "${year.name}" set as current active session!'),
          ),
        );
        _loadAcademicYears();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.softCoral, content: Text('Failed to set active session: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete(AcademicYearModel year) async {
    final profile = ref.read(authProvider);
    final schoolId = profile?.schoolId?.trim() ?? '';
    final service = ref.read(academicYearServiceProvider);

    // 1. Inspect dependencies
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<String> dependencies = [];
    try {
      dependencies = await service.checkDependentRecords(id: year.id, schoolId: schoolId);
    } catch (_) {}

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // pop progress
    }

    if (!mounted) return;

    if (dependencies.isNotEmpty) {
      // Deletion blocked
      showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.softCoral),
                const SizedBox(width: 8),
                Text('Cannot Delete Academic Year', style: AppTypography.titleMedium.copyWith(color: AppColors.softCoral)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Academic Year "${year.name}" is actively referenced by:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                ),
                const SizedBox(height: 10),
                ...dependencies.map(
                  (dep) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: AppColors.amberDark),
                        const SizedBox(width: 8),
                        Expanded(child: Text(dep, style: AppTypography.bodySmall.copyWith(color: AppColors.amberDark))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.midnightNavy.withValues(alpha: 0.5) : AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  ),
                  child: Text(
                    'To preserve historical records, student enrolments, and financial integrity, '
                    'please toggle this academic year to INACTIVE instead of deleting it.',
                    style: AppTypography.bodySmall.copyWith(color: isDark ? AppColors.coolGray : AppColors.secondaryText),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleStatus(year);
                },
                child: const Text('Deactivate Instead'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Confirmation for safe delete
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
          title: Text('Delete Academic Year?', style: AppTypography.titleMedium.copyWith(color: AppColors.softCoral)),
          content: Text(
            'Are you sure you want to permanently delete "${year.name}"? This action cannot be undone.',
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await service.deleteAcademicYear(id: year.id, schoolId: schoolId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.mutedGreen,
                        content: Text('Academic Year "${year.name}" deleted.'),
                      ),
                    );
                    _loadAcademicYears();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.softCoral, content: Text('$e')),
                    );
                  }
                }
              },
              child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/settings'),
        leadingWidth: 96.0,
        title: Text('Academic Years', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAcademicYears,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.softCoral),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: AppTypography.bodyMedium),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadAcademicYears, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header Card
                    BentoCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_month_rounded, color: AppColors.softLavender, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.schoolName ?? 'School Institution',
                                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentYear != null
                                      ? 'Current Active Session: ${_currentYear!.name}'
                                      : 'No active session within current calendar window',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: _currentYear != null ? AppColors.mutedGreen : AppColors.amberDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.softLavender,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create Academic Year', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _showCreateDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Academic Years List
                    if (_years.isEmpty)
                      BentoCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.coolGray),
                                const SizedBox(height: 12),
                                Text(
                                  'No Academic Years Configured',
                                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create the first academic session (e.g. 2026-2027) to begin scheduling classes, enrolling students, and configuring fee structures.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Create First Academic Year'),
                                  onPressed: _showCreateDialog,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._years.map((year) {
                        final isCurrent = _currentYear?.id == year.id;
                        final isActive = year.status == AccountStatus.active;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BentoCard(
                            border: isCurrent
                                ? Border.all(color: AppColors.softLavender, width: 1.5)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Session Name
                                    Text(
                                      year.name,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Current Year Badge
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.softLavender.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.softLavender, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 14, color: AppColors.softLavender),
                                            const SizedBox(width: 4),
                                            Text(
                                              'CURRENT YEAR',
                                              style: AppTypography.labelSmall.copyWith(
                                                color: AppColors.softLavender,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    const Spacer(),

                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.mutedGreen.withValues(alpha: 0.15)
                                            : AppColors.coolGray.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isActive ? 'ACTIVE' : 'INACTIVE',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: isActive ? AppColors.mutedGreen : AppColors.coolGray,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Date range display
                                Row(
                                  children: [
                                    const Icon(Icons.date_range_outlined, size: 16, color: AppColors.coolGray),
                                    const SizedBox(width: 6),
                                    Text(
                                      year.dateRangeFormatted,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? AppColors.pureWhite
                                            : AppColors.midnightNavy,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 10),

                                // Actions row
                                Builder(
                                  builder: (ctx) {
                                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                                    return Wrap(
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        // Set as Current Session button
                                        if (!isCurrent && isActive)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.softLavender,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            icon: const Icon(Icons.star_outline_rounded, size: 14),
                                            label: const Text('Set Current'),
                                            onPressed: () => _makeCurrentSession(year),
                                          ),

                                        // Status toggle (Activate / Deactivate)
                                        TextButton.icon(
                                          icon: Icon(
                                            isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                            color: isActive ? AppColors.amberDark : AppColors.mutedGreen,
                                            size: 18,
                                          ),
                                          label: Text(
                                            isActive ? 'Deactivate' : 'Activate',
                                            style: TextStyle(
                                              color: isActive ? AppColors.amberDark : AppColors.mutedGreen,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          onPressed: () => _toggleStatus(year),
                                        ),

                                        // Edit button
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                                            side: BorderSide(
                                              color: isDark ? AppColors.coolGray : AppColors.border,
                                              width: 1,
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          icon: const Icon(Icons.edit_outlined, size: 14),
                                          label: const Text('Edit'),
                                          onPressed: () => _showEditDialog(year),
                                        ),

                                        // Delete button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.softCoral, size: 20),
                                          tooltip: 'Delete Academic Year',
                                          onPressed: () => _handleDelete(year),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}

class AcademicYearDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final List<AcademicYearModel> existingYears;
  final AcademicYearModel? initialModel;
  final Future<void> Function(String name, DateTime start, DateTime end, AccountStatus status) onSubmit;

  const AcademicYearDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.existingYears,
    this.initialModel,
    required this.onSubmit,
  });

  @override
  State<AcademicYearDialog> createState() => _AcademicYearDialogState();
}

class _AcademicYearDialogState extends State<AcademicYearDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  late AccountStatus _status;
  bool _isSubmitting = false;
  String? _dialogError;

  @override
  void initState() {
    super.initState();
    final m = widget.initialModel;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _startDate = m?.startDate ?? DateTime(DateTime.now().year, 4, 1);
    _endDate = m?.endDate ?? DateTime(DateTime.now().year + 1, 3, 31);
    _status = m?.status ?? AccountStatus.active;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: AppColors.softLavender,
                  surface: AppColors.darkSurfaceVariant,
                  onSurface: AppColors.pureWhite,
                )
              : const ColorScheme.light(
                  primary: AppColors.indigo,
                  surface: Colors.white,
                  onSurface: AppColors.midnightNavy,
                ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 364));
          }
        } else {
          _endDate = picked;
        }
        _dialogError = null;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      setState(() => _dialogError = 'Start and End dates are required.');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _dialogError = 'End date cannot be before start date.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
    });

    try {
      await widget.onSubmit(
        _nameCtrl.text.trim(),
        _startDate!,
        _endDate!,
        _status,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dialogError = e.toString().replaceAll('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      title: Text(
        widget.title,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
        ),
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dialogError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.softCoral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.softCoral, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.softCoral),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dialogError!,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Name Input
                Text(
                  'ACADEMIC YEAR NAME',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.softLavender : AppColors.indigo,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 2026-2027',
                    prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Academic year name cannot be empty.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date Selectors
                Row(
                  children: [
                    // Start Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START DATE',
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark ? AppColors.softLavender : AppColors.indigo,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickDate(isStart: true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.mainBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: isDark ? AppColors.softLavender : AppColors.indigo),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _startDate != null ? df.format(_startDate!) : 'Select',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // End Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'END DATE',
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark ? AppColors.softLavender : AppColors.indigo,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickDate(isStart: false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.mainBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_available_rounded, size: 16, color: isDark ? AppColors.softLavender : AppColors.indigo),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _endDate != null ? df.format(_endDate!) : 'Select',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Status Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operational Status',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                            ),
                          ),
                          Text(
                            _status == AccountStatus.active
                                ? 'Active: available for attendance, fees & classes'
                                : 'Inactive: historical records preserved, restricted from new entries',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _status == AccountStatus.active,
                      activeColor: AppColors.mutedGreen,
                      onChanged: (val) {
                        setState(() {
                          _status = val ? AccountStatus.active : AccountStatus.inactive;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
          onPressed: _isSubmitting ? null : _handleSave,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite))
              : Text(widget.submitLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}
