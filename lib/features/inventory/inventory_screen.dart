import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';

class InventoryItemModel {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final int minThreshold;
  final double unitPrice;
  final String location;
  final String lastRestocked;
  final String? assignedTo;

  InventoryItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minThreshold,
    required this.unitPrice,
    required this.location,
    required this.lastRestocked,
    this.assignedTo,
  });

  bool get isLowStock => quantity <= minThreshold && quantity > 0;
  bool get isOutOfStock => quantity <= 0;

  InventoryItemModel copyWith({
    int? quantity,
    String? lastRestocked,
    String? assignedTo,
  }) {
    return InventoryItemModel(
      id: id,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      minThreshold: minThreshold,
      unitPrice: unitPrice,
      location: location,
      lastRestocked: lastRestocked ?? this.lastRestocked,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  final List<InventoryItemModel> _items = [
    InventoryItemModel(
      id: 'inv-001',
      name: 'Compound Optical Microscopes (1000x)',
      category: 'Lab & Science',
      quantity: 18,
      minThreshold: 5,
      unitPrice: 12500.0,
      location: 'Biology Lab (Room 204)',
      lastRestocked: '2026-09-15',
    ),
    InventoryItemModel(
      id: 'inv-002',
      name: 'Soccer Balls (Size 5 Tournament Edition)',
      category: 'Sports & PE',
      quantity: 4,
      minThreshold: 8,
      unitPrice: 1200.0,
      location: 'Sports Equipment Room',
      lastRestocked: '2026-08-10',
    ),
    InventoryItemModel(
      id: 'inv-003',
      name: 'Interactive Smartboard Projectors',
      category: 'Electronics & AV',
      quantity: 12,
      minThreshold: 2,
      unitPrice: 45000.0,
      location: 'AV Storage Locker',
      lastRestocked: '2026-07-22',
      assignedTo: 'Classes 9A, 10A, 11A',
    ),
    InventoryItemModel(
      id: 'inv-004',
      name: 'A4 Ruled Examination Answer Booklets',
      category: 'Stationery',
      quantity: 1450,
      minThreshold: 500,
      unitPrice: 15.0,
      location: 'Central Examination Depot',
      lastRestocked: '2026-10-01',
    ),
    InventoryItemModel(
      id: 'inv-005',
      name: 'Adjustable Dual-Student Desks & Benches',
      category: 'Furniture',
      quantity: 65,
      minThreshold: 10,
      unitPrice: 3800.0,
      location: 'Campus Warehouse Bay 2',
      lastRestocked: '2026-06-18',
    ),
    InventoryItemModel(
      id: 'inv-006',
      name: 'Physics Multimeter Digital Probes',
      category: 'Lab & Science',
      quantity: 2,
      minThreshold: 6,
      unitPrice: 2200.0,
      location: 'Physics Lab (Room 201)',
      lastRestocked: '2026-05-11',
    ),
    InventoryItemModel(
      id: 'inv-007',
      name: 'Badminton Rackets & Shuttlecock Tubes',
      category: 'Sports & PE',
      quantity: 0,
      minThreshold: 10,
      unitPrice: 850.0,
      location: 'Sports Locker Bay',
      lastRestocked: '2026-04-12',
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Lab & Science');
    final qtyCtrl = TextEditingController(text: '10');
    final minCtrl = TextEditingController(text: '3');
    final priceCtrl = TextEditingController(text: '1000');
    final locCtrl = TextEditingController(text: 'Main Depot');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Register New Inventory Asset', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Asset Name *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter item name' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: catCtrl.text,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Lab & Science', 'Sports & PE', 'Electronics & AV', 'Stationery', 'Furniture']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => catCtrl.text = v ?? 'Stationery',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid qty' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min Alert Qty', border: OutlineInputBorder()),
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Unit Price (₹)', border: OutlineInputBorder()),
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid price' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: locCtrl,
                        decoration: const InputDecoration(labelText: 'Storage Location', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                _items.insert(
                  0,
                  InventoryItemModel(
                    id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    category: catCtrl.text,
                    quantity: int.parse(qtyCtrl.text.trim()),
                    minThreshold: int.parse(minCtrl.text.trim()),
                    unitPrice: double.parse(priceCtrl.text.trim()),
                    location: locCtrl.text.trim(),
                    lastRestocked: DateTime.now().toIso8601String().substring(0, 10),
                  ),
                );
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Inventory asset added successfully!')),
              );
            },
            child: const Text('Add Asset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(InventoryItemModel item) {
    final qtyCtrl = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Restock "${item.name}"', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${item.quantity} units', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Units to Add', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
            onPressed: () {
              final added = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (added > 0) {
                setState(() {
                  final idx = _items.indexWhere((i) => i.id == item.id);
                  if (idx != -1) {
                    _items[idx] = item.copyWith(
                      quantity: item.quantity + added,
                      lastRestocked: DateTime.now().toIso8601String().substring(0, 10),
                    );
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Restocked $added units of ${item.name}!')),
                );
              }
            },
            child: const Text('Confirm Restock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _items.fold<int>(0, (sum, i) => sum + i.quantity);
    final lowStockCount = _items.where((i) => i.isLowStock || i.isOutOfStock).length;
    final totalValuation = _items.fold<double>(0.0, (sum, i) => sum + (i.quantity * i.unitPrice));

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _items.where((i) {
      final matchesCat = _selectedCategory == 'All' || i.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesQuery = query.isEmpty || i.name.toLowerCase().contains(query) || i.location.toLowerCase().contains(query);
      return matchesCat && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Inventory & Asset Depot', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded),
            tooltip: 'Add Inventory Asset',
            onPressed: _showAddItemDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Row
            Row(
              children: [
                Expanded(
                  child: BentoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL ASSETS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                        const SizedBox(height: 6),
                        Text('$totalItems', style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.midnightNavy)),
                        Text('${_items.length} Unique SKUs', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BentoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LOW / OUT OF STOCK', style: AppTypography.labelSmall.copyWith(color: AppColors.softCoral)),
                        const SizedBox(height: 6),
                        Text('$lowStockCount', style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.softCoral)),
                        Text('Action required', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BentoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ASSET VALUATION', style: AppTypography.labelSmall.copyWith(color: AppColors.mutedGreen)),
                        const SizedBox(height: 6),
                        Text('₹${(totalValuation / 1000).toStringAsFixed(1)}k', style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.mutedGreen)),
                        Text('Audited depot value', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Chips
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search items by asset name or location...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.coolGray),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _searchCtrl.clear()))
                    : null,
                filled: true,
                fillColor: AppColors.pureWhite,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Lab & Science', 'Sports & PE', 'Electronics & AV', 'Stationery', 'Furniture'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.softLavender.withOpacity(0.2),
                      checkmarkColor: AppColors.softLavender,
                      labelStyle: AppTypography.bodySmall.copyWith(
                        color: isSelected ? AppColors.softLavender : AppColors.coolGrayDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Asset Cards List
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.coolGray),
                      const SizedBox(height: 12),
                      Text('No Inventory Items Found', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Try adjusting your search criteria or register a new asset.', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  Color statusBg = AppColors.greenLight;
                  Color statusColor = AppColors.greenDark;
                  String statusText = 'IN STOCK (${item.quantity})';

                  if (item.isOutOfStock) {
                    statusBg = AppColors.coralLight;
                    statusColor = AppColors.coralDark;
                    statusText = 'OUT OF STOCK';
                  } else if (item.isLowStock) {
                    statusBg = AppColors.amberLight;
                    statusColor = AppColors.amberDark;
                    statusText = 'LOW STOCK (${item.quantity})';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BentoCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, color: AppColors.softLavender, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(item.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                      child: Text(statusText, style: AppTypography.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${item.category} • Location: ${item.location}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text('Unit Value: ₹${item.unitPrice.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                    Text('Restocked: ${item.lastRestocked}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                                    if (item.assignedTo != null)
                                      Text('Assigned: ${item.assignedTo}', style: AppTypography.bodySmall.copyWith(color: AppColors.amberDark, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.coolGray),
                            onSelected: (v) {
                              if (v == 'restock') {
                                _showRestockDialog(item);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'restock', child: Text('Adjust / Restock')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
