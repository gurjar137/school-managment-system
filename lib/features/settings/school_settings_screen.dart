import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/school_management_models.dart';

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
  late TextEditingController _yearCtrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final service = ref.read(schoolManagementServiceProvider);
    final settings = await service.getSchoolSettings();

    _nameCtrl = TextEditingController(text: settings.name);
    _addressCtrl = TextEditingController(text: settings.address);
    _phoneCtrl = TextEditingController(text: settings.phone);
    _emailCtrl = TextEditingController(text: settings.email);
    _yearCtrl = TextEditingController(text: settings.academicYear);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final updated = SchoolSettingsModel(
        schoolId: 'SCH-2026-DELHI',
        name: _nameCtrl.text,
        logoUrl: 'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=150',
        address: _addressCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        academicYear: _yearCtrl.text,
        activeClasses: ['1', '2', '3', '8', '9', '10'],
        activeSubjects: ['Mathematics', 'Science', 'English', 'Hindi', 'Computer'],
      );

      await ref.read(schoolManagementServiceProvider).updateSchoolSettings(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('School Configuration saved successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingStateWidget(message: 'Loading school configuration...'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('School Configuration', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.softLavender),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INSTITUTION PROFILE', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'School Name')),
              const SizedBox(height: 12),
              TextFormField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Campus Address')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Helpline Phone'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Official Email'))),
                ],
              ),
              const SizedBox(height: 24),

              Text('ACADEMIC CONFIGURATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              TextFormField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'Active Academic Session')),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Save School Configuration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
