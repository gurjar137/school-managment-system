import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/school_management_models.dart';
import '../../data/models/school_model.dart';
import '../../data/services/tenant_resolver.dart';

class SchoolSettingsScreen extends ConsumerStatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  ConsumerState<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends ConsumerState<SchoolSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  String? _resolvedSchoolId;
  String? _selectedYearId;
  List<AcademicYearModel> _availableYears = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  String _initialName = '';
  String _initialAddress = '';
  String _initialPhone = '';
  String _initialEmail = '';
  String? _initialYearId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authProvider);
      String schoolId = user?.schoolId?.trim() ?? '';
      if (schoolId.isEmpty) {
        schoolId = await TenantResolver.resolveActiveSchoolId();
      }
      _resolvedSchoolId = schoolId;

      final schoolService = ref.read(schoolServiceProvider);
      final academicYearService = ref.read(academicYearServiceProvider);

      final SchoolModel school = await schoolService.fetchSchoolProfile(schoolId);
      final List<AcademicYearModel> years = await academicYearService.fetchAcademicYears(schoolId);
      final AcademicYearModel? activeYear = years.isNotEmpty
          ? years.firstWhere((y) => y.isCurrent, orElse: () => years.first)
          : null;

      _nameCtrl.text = school.name != 'School' ? school.name : (user?.schoolName ?? 'School');
      _addressCtrl.text = school.address ?? '';
      _phoneCtrl.text = school.phone ?? '';
      _emailCtrl.text = school.email ?? '';

      _availableYears = years;
      _selectedYearId = activeYear?.id;

      _initialName = _nameCtrl.text;
      _initialAddress = _addressCtrl.text;
      _initialPhone = _phoneCtrl.text;
      _initialEmail = _emailCtrl.text;
      _initialYearId = _selectedYearId;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[SchoolSettingsScreen _loadSettings error]: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _nameCtrl.text != _initialName ||
      _addressCtrl.text != _initialAddress ||
      _phoneCtrl.text != _initialPhone ||
      _emailCtrl.text != _initialEmail ||
      _selectedYearId != _initialYearId;

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: const Text('You have modified the school configuration without saving. Do you want to discard your changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final schoolId = _resolvedSchoolId;
    if (schoolId == null || schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.softCoral,
          content: Text('Cannot save: No valid authenticated school ID found.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final schoolService = ref.read(schoolServiceProvider);
      final academicYearService = ref.read(academicYearServiceProvider);

      // 1. Persist to public.schools table
      await schoolService.updateSchoolProfile(
        schoolId: schoolId,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      // 2. Validate & Persist Active Academic Year if changed
      if (_selectedYearId != null) {
        final isValidSession = _availableYears.any((y) => y.id == _selectedYearId);
        if (!isValidSession) {
          throw Exception('The selected academic session does not belong to this verified school.');
        }

        if (_selectedYearId != _initialYearId) {
          await academicYearService.setCurrentAcademicYear(
            id: _selectedYearId!,
            schoolId: schoolId,
          );
        }
      }

      // 3. Keep local in-memory SchoolManagementService in sync
      final selectedYearName = _availableYears
          .firstWhere(
            (y) => y.id == _selectedYearId,
            orElse: () => _availableYears.isNotEmpty
                ? _availableYears.first
                : AcademicYearModel(
                    id: '',
                    schoolId: '',
                    name: '2026-27',
                    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  ),
          )
          .name;

      final updatedLocal = SchoolSettingsModel(
        schoolId: schoolId,
        name: _nameCtrl.text.trim(),
        logoUrl: 'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=150',
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        academicYear: selectedYearName,
        activeClasses: ['1', '2', '3', '8', '9', '10'],
        activeSubjects: ['Mathematics', 'Science', 'English', 'Hindi', 'Computer'],
      );
      await ref.read(schoolManagementServiceProvider).updateSchoolSettings(updatedLocal);

      // 4. Invalidate providers across the app
      ref.invalidate(currentSchoolProvider);
      ref.invalidate(adminDashboardMetricsProvider);
      ref.invalidate(appAccessStateProvider);
      await ref.read(authProvider.notifier).refreshProfile();

      // 5. Reload persisted values from Supabase
      await _loadSettings();

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.mutedGreen,
            content: Text('School Configuration saved successfully!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[SchoolSettingsScreen save error]: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.softCoral,
            content: Text('Failed to save configuration: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingStateWidget(message: 'Loading school configuration...'));
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            fallbackPath: '/settings',
            onBeforeBack: () async {
              return await _onWillPop();
            },
          ),
          leadingWidth: 96.0,
          title: Text('School Configuration', style: AppTypography.titleLarge),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.softLavender),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check_rounded, color: AppColors.softLavender),
                tooltip: 'Save Configuration',
                onPressed: _saveSettings,
              ),
          ],
        ),
        body: _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INSTITUTION PROFILE', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'School Name *',
                          hintText: 'Enter official institution name',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'School name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Campus Address',
                          hintText: 'e.g. Ring Road Campus, New Delhi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Helpline Phone',
                                hintText: 'e.g. +91 11 2614 8920',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Official Email',
                                hintText: 'contact@institution.edu',
                              ),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'Invalid email format';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text('ACADEMIC CONFIGURATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                      const SizedBox(height: 10),

                      if (_availableYears.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Academic Years Found',
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please create an academic year session before configuring active classes.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/academic-years'),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Manage Academic Sessions'),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedYearId,
                          decoration: const InputDecoration(
                            labelText: 'Active Academic Session *',
                            helperText: 'Select the primary operating session for timetable & enrollment',
                          ),
                          items: _availableYears.map((year) {
                            return DropdownMenuItem<String>(
                              value: year.id,
                              child: Text(
                                '${year.name} (${year.status.name.toUpperCase()}${year.isCurrent ? ' • CURRENT' : ''})',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedYearId = val);
                            }
                          },
                        ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save School Configuration'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
