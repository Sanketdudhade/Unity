import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Screen for creating a new Material Master record with integer base units.
class AddMaterialScreen extends ConsumerStatefulWidget {
  const AddMaterialScreen({super.key});

  @override
  ConsumerState<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends ConsumerState<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController(text: 'Warehouse A - Bay 01');
  final _notesController = TextEditingController();
  final _minStockController = TextEditingController(text: '20');
  final _initialStockController = TextEditingController(text: '100');

  String _selectedCategory = 'RAW_MATERIAL';
  String _selectedUnit = 'PCS';
  int _unitScale = 1;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _units = [
    {'name': 'PCS (Pieces / Discrete)', 'unit': 'PCS', 'scale': 1},
    {'name': 'KG (Kilograms / Decimal 3 places)', 'unit': 'KG', 'scale': 1000},
    {'name': 'METER (Length / Decimal 3 places)', 'unit': 'METER', 'scale': 1000},
    {'name': 'LITER (Volume / Decimal 3 places)', 'unit': 'LITER', 'scale': 1000},
    {'name': 'SHEET (Metal Plates)', 'unit': 'SHEET', 'scale': 1},
    {'name': 'BAR (Extruded Rods)', 'unit': 'BAR', 'scale': 1},
  ];

  final List<String> _categories = [
    'RAW_MATERIAL',
    'SHEET_METAL',
    'HARDWARE',
    'FASTENER',
    'CONSUMABLE',
    'PACKAGING',
  ];

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _minStockController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;
    if (orgId == null || orgId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cannot create material: Organization missing.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final minStockVal = double.tryParse(_minStockController.text.trim()) ?? 0.0;
    final initialStockVal = double.tryParse(_initialStockController.text.trim()) ?? 0.0;

    final minStockBaseUnits = _unitScale > 1
        ? (minStockVal * _unitScale).round()
        : minStockVal.round();
    final initialStockBaseUnits = _unitScale > 1
        ? (initialStockVal * _unitScale).round()
        : initialStockVal.round();

    final material = MaterialModel(
      id: '',
      sku: _skuController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      unit: _selectedUnit,
      unitScale: _unitScale,
      minimumStock: minStockBaseUnits,
      defaultLocation: _locationController.text.trim(),
      notes: _notesController.text.trim(),
    );

    try {
      await ref.read(inventoryRepositoryProvider).createMaterial(
            orgId: orgId,
            material: material,
            initialQuantity: initialStockBaseUnits,
            actorUid: user?.uid ?? 'admin',
            actorName: user?.fullName ?? 'Administrator',
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Created material ${material.sku} with $initialStockVal $_selectedUnit initial stock.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/admin/inventory');
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error creating material: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Material Master'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Material Master Details', style: AppTextStyles.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'SKU / Material Code *',
                  hintText: 'e.g. MAT-AL-6061',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Material Name *',
                  hintText: 'e.g. Aluminum 6061 Round Bar Ø50mm',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Standard Unit of Measure *',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                items: _units.map((u) {
                  return DropdownMenuItem<String>(
                    value: u['unit'] as String,
                    child: Text(u['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final item = _units.firstWhere((e) => e['unit'] == val);
                    setState(() {
                      _selectedUnit = val;
                      _unitScale = item['scale'] as int;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Min Safety Stock ($_selectedUnit)',
                        prefixIcon: const Icon(Icons.shield_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _initialStockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Initial Opening Stock ($_selectedUnit)',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Default Warehouse Location',
                  hintText: 'e.g. Warehouse A - Bay 04',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / Supplier Specs',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSubmitting ? 'Saving Material...' : 'Create Material Master'),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
