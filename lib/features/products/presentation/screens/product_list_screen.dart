import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/products/presentation/providers/product_providers.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditProductDialog(BuildContext context, String orgId, [ProductModel? existing]) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();

    final codeController = TextEditingController(text: existing?.partCode ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final dwgController = TextEditingController(text: existing?.drawingNumber ?? '');
    final revController = TextEditingController(text: existing?.revision ?? 'Rev A');
    final unitController = TextEditingController(text: existing?.unit ?? 'PCS');
    final custController = TextEditingController(text: existing?.customerReference ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  existing == null ? Icons.add_box_rounded : Icons.edit_note_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(existing == null ? 'Add Product Master' : 'Edit Product Master', style: AppTextStyles.titleMedium),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'Part Code / SKU *',
                        hintText: 'e.g. PRD-BRACKET-01',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Part code is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product / Part Name *',
                        hintText: 'e.g. Stainless Steel Mounting Bracket',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: dwgController,
                            decoration: const InputDecoration(
                              labelText: 'Drawing Number',
                              hintText: 'e.g. DWG-2026-A10',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: revController,
                            decoration: const InputDecoration(
                              labelText: 'Revision',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: unitController,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: custController,
                            decoration: const InputDecoration(
                              labelText: 'Customer Reference',
                              hintText: 'e.g. AeroTech Systems',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Specifications',
                        hintText: 'e.g. 316L Sheet 2mm, tolerance ISO 2768-m',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      final prod = ProductModel(
                        id: existing?.id ?? '',
                        partCode: codeController.text.trim(),
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        drawingNumber: dwgController.text.trim(),
                        revision: revController.text.trim(),
                        unit: unitController.text.trim(),
                        customerReference: custController.text.trim(),
                        isActive: existing?.isActive ?? true,
                      );

                      try {
                        if (existing == null) {
                          await ref.read(productRepositoryProvider).createProduct(orgId, prod);
                        } else {
                          await ref.read(productRepositoryProvider).updateProduct(orgId, prod);
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Product ${prod.partCode} saved successfully!'),
                              backgroundColor: AppColors.secondary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(existing == null ? 'Create Product' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Master & Parts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditProductDialog(context, orgId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Part'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: productsAsync.when(
        loading: () => const LoadingWidget(message: 'Loading product catalog...'),
        error: (err, _) => Center(
          child: Text('Error loading products: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (products) {
          final query = _searchController.text.trim().toLowerCase();
          final filtered = products.where((p) {
            final matchesFilter = _selectedFilter == 'All' ||
                (_selectedFilter == 'Active' && p.isActive) ||
                (_selectedFilter == 'Inactive' && !p.isActive);

            final matchesQuery = query.isEmpty ||
                p.partCode.toLowerCase().contains(query) ||
                p.name.toLowerCase().contains(query) ||
                p.drawingNumber.toLowerCase().contains(query) ||
                p.customerReference.toLowerCase().contains(query);

            return matchesFilter && matchesQuery;
          }).toList();

          final activeCount = products.where((p) => p.isActive).length;
          final inactiveCount = products.where((p) => !p.isActive).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productsStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _MiniProductCard(
                      label: 'Total Parts',
                      count: products.length,
                      color: AppColors.secondary,
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MiniProductCard(
                      label: 'Active',
                      count: activeCount,
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MiniProductCard(
                      label: 'Inactive',
                      count: inactiveCount,
                      color: AppColors.textMuted,
                      icon: Icons.pause_circle_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Part Code, Name, Drawing, or Customer...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Filter Chips
                Row(
                  children: ['All', 'Active', 'Inactive'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(filter),
                        selectedColor: AppColors.primaryLight,
                        labelStyle: AppTextStyles.labelSmall.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.category_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          products.isEmpty
                              ? 'No products in catalog yet.\nTap "Add Part" to register a manufactured component.'
                              : 'No products match your filter criteria.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((prod) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  prod.partCode,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  prod.revision,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.secondaryDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: prod.isActive ? AppColors.successLight : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  prod.isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: prod.isActive ? AppColors.success : AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(prod.name, style: AppTextStyles.titleMedium),
                          if (prod.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              prod.description,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              if (prod.drawingNumber.isNotEmpty) ...[
                                const Icon(Icons.architecture_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text('Dwg: ${prod.drawingNumber}', style: AppTextStyles.labelSmall),
                                const SizedBox(width: 14),
                              ],
                              if (prod.customerReference.isNotEmpty) ...[
                                const Icon(Icons.business_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(prod.customerReference, style: AppTextStyles.labelSmall),
                                const SizedBox(width: 14),
                              ],
                              const Icon(Icons.straighten_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text('Unit: ${prod.unit}', style: AppTextStyles.labelSmall),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showAddEditProductDialog(context, orgId, prod),
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: AppTextStyles.labelSmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await ref.read(productRepositoryProvider).toggleProductStatus(
                                    orgId,
                                    prod.id,
                                    !prod.isActive,
                                  );
                                },
                                icon: Icon(
                                  prod.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                  size: 16,
                                  color: prod.isActive ? AppColors.success : AppColors.textMuted,
                                ),
                                label: Text(prod.isActive ? 'Active' : 'Inactive'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: AppTextStyles.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniProductCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
