import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/empty_state.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
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
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final router = GoRouter.of(context);
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
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  existing == null ? Icons.add_box_rounded : Icons.edit_note_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                existing == null ? 'Add Product Master' : 'Edit Product Master',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
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
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Part code is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product / Part Name *',
                        hintText: 'e.g. Stainless Steel Mounting Bracket',
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
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 3),
                              content: Text('Product ${prod.partCode} saved! Live in Production catalog.'),
                              backgroundColor: tokens.success,
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'Go to Production',
                                textColor: Colors.white,
                                onPressed: () {
                                  messenger.hideCurrentSnackBar();
                                  router.push(RouteNames.adminProduction);
                                },
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 3),
                            content: Text('Failed: $e'),
                            backgroundColor: tokens.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Page Header
          AdminPageHeader(
            title: 'Product Master & Parts',
            subtitle: 'Central catalog of manufactured parts, engineering drawings, and specifications',
            icon: Icons.precision_manufacturing_rounded,
            trailing: ElevatedButton.icon(
              onPressed: () => _showAddEditProductDialog(context, orgId),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Part'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // 2. Metrics & Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF152235) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: productsAsync.maybeWhen(
              data: (products) {
                final activeCount = products.where((p) => p.isActive).length;
                final inactiveCount = products.where((p) => !p.isActive).length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;

                    final metricCards = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniProductBadge(
                          label: 'Total Parts',
                          count: products.length,
                          color: theme.colorScheme.primary,
                          icon: Icons.category_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MiniProductBadge(
                          label: 'Active',
                          count: activeCount,
                          color: tokens.success,
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MiniProductBadge(
                          label: 'Inactive',
                          count: inactiveCount,
                          color: theme.colorScheme.onSurfaceVariant,
                          icon: Icons.pause_circle_outline_rounded,
                        ),
                      ],
                    );

                    final searchField = SizedBox(
                      width: isWide ? 300 : double.infinity,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search code, name, drawing...',
                          hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0E1728) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    );

                    final filterRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['All', 'Active', 'Inactive'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedFilter = filter),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isDark ? const Color(0xFF0E1728) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          metricCards,
                          const Spacer(),
                          searchField,
                          const SizedBox(width: 10),
                          filterRow,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: metricCards,
                          ),
                          const SizedBox(height: 10),
                          searchField,
                          const SizedBox(height: 8),
                          filterRow,
                        ],
                      );
                    }
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // 3. Product Catalog List
          Expanded(
            child: productsAsync.when(
              loading: () => const LoadingWidget(message: 'Loading product catalog...'),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading products: $err', style: TextStyle(color: tokens.danger)),
                ),
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

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.category_outlined,
                    title: products.isEmpty ? 'No products in catalog yet' : 'No matching products',
                    description: products.isEmpty
                        ? 'Tap "Add Part" to register your first manufactured component.'
                        : 'No parts match your filter criteria "$query".',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsStreamProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final prod = filtered[index];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tokens.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    prod.partCode,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    prod.revision,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                StatusChip(
                                  label: prod.isActive ? 'ACTIVE' : 'INACTIVE',
                                  variant: prod.isActive ? StatusVariant.success : StatusVariant.neutral,
                                  icon: prod.isActive ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prod.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (prod.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                prod.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                if (prod.drawingNumber.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.architecture_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Dwg: ${prod.drawingNumber}',
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                if (prod.customerReference.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.business_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        prod.customerReference,
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.straighten_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Unit: ${prod.unit}',
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => context.push(RouteNames.adminProduction),
                                  icon: const Icon(Icons.precision_manufacturing_rounded, size: 14),
                                  label: const Text('Produce / Order'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showAddEditProductDialog(context, orgId, prod),
                                  icon: const Icon(Icons.edit_outlined, size: 14),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                                    color: prod.isActive ? tokens.success : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  label: Text(prod.isActive ? 'Active' : 'Inactive'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProductBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniProductBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1728) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
