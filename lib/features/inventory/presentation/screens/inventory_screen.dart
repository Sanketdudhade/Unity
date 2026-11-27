import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/empty_state.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/inventory/presentation/screens/add_material_screen.dart';
import 'package:unity/features/inventory/presentation/screens/low_stock_screen.dart';
import 'package:unity/features/inventory/presentation/screens/product_boms_tab.dart';
import 'package:unity/features/inventory/presentation/screens/stock_history_screen.dart';

/// Comprehensive Inventory & Stock Management Portal for Manufacturing.
/// Backed by real-time Stock Balances and Authoritative Immutable Transaction Ledger.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'RAW_MATERIAL',
    'SHEET_METAL',
    'HARDWARE',
    'FASTENER',
    'CONSUMABLE',
    'PACKAGING',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickTransactionDialog(BuildContext context, StockBalanceModel balance, bool isReceipt) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;

    final qtyController = TextEditingController(text: isReceipt ? '50' : '10');
    final refController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        title: Text(
          isReceipt ? 'Receive Stock (GRN)' : 'Issue Material to Floor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: min(420.0, MediaQuery.sizeOf(context).width - 32),
          ),
          child: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${balance.materialName} (${balance.materialSku})',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available Stock: ${balance.formattedAvailable} ${balance.unit}',
                    style: TextStyle(
                      color: balance.availableQuantity > 0 ? tokens.success : tokens.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Quantity (${balance.unit}) *',
                      prefixIcon: Icon(isReceipt ? Icons.add_box_outlined : Icons.indeterminate_check_box_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      labelText: isReceipt ? 'Supplier PO / Invoice Ref' : 'Work Order # / Job Ref',
                      prefixIcon: const Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Reason / Department Notes',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReceipt ? tokens.success : tokens.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final rawQty = double.tryParse(qtyController.text.trim());
              if (rawQty == null || rawQty <= 0) return;

              final baseUnits = balance.unitScale > 1
                  ? (rawQty * balance.unitScale).round()
                  : rawQty.round();

              Navigator.pop(ctx);

              try {
                await ref.read(inventoryRepositoryProvider).recordTransaction(
                      orgId: orgId,
                      materialId: balance.materialId,
                      materialSku: balance.materialSku,
                      materialName: balance.materialName,
                      type: isReceipt ? 'RECEIPT' : 'ISSUE',
                      quantityDelta: isReceipt ? baseUnits : -baseUnits,
                      locationId: balance.locationId,
                      locationName: balance.locationName,
                      performedByUid: user?.uid ?? 'user',
                      performedByName: user?.fullName ?? 'Operator',
                      referenceNumber: refController.text.trim(),
                      notes: notesController.text.trim(),
                      orderId: !isReceipt && refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                      unit: balance.unit,
                      unitScale: balance.unitScale,
                    );

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${isReceipt ? "Received" : "Issued"} $rawQty ${balance.unit} of ${balance.materialName}.',
                    ),
                    backgroundColor: isReceipt ? tokens.success : theme.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Transaction failed: $e'),
                    backgroundColor: tokens.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(isReceipt ? 'Confirm Receipt' : 'Confirm Issue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final balancesAsync = ref.watch(stockBalancesStreamProvider);
    final lowStockAsync = ref.watch(lowStockBalancesStreamProvider);
    final lowStockCount = lowStockAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Page Header with Integrated TabBar
          AdminPageHeader(
            title: 'Inventory & Materials',
            subtitle: 'Real-time stock balance ledger, material movement tracking, and safety thresholds',
            icon: Icons.inventory_2_rounded,
            trailing: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
                );
              },
              icon: const Icon(Icons.add_box_rounded, size: 18),
              label: const Text('Add Material'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 2.5,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Materials & Stock'),
                const Tab(text: 'Transaction Ledger'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Low Stock Alerts'),
                      if (lowStockCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$lowStockCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Product BOMs'),
              ],
            ),
          ),

          // 2. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMaterialsListTab(balancesAsync),
                _buildLedgerTab(),
                const LowStockScreen(isEmbedded: true),
                const ProductBomsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsListTab(AsyncValue<List<StockBalanceModel>> balancesAsync) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;

    return Column(
      children: [
        // Search & Category Filters
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search SKU, material name, or location...',
                    hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
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
                            cat,
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
                ),
              ),
            ],
          ),
        ),

        // Balances List
        Expanded(
          child: balancesAsync.when(
            loading: () => const LoadingWidget(message: 'Loading inventory balances...'),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Failed to load inventory: $err', style: TextStyle(color: tokens.danger)),
              ),
            ),
            data: (balances) {
              final query = _searchController.text.toLowerCase().trim();
              final filtered = balances.where((b) {
                final matchesQuery = query.isEmpty ||
                    b.materialName.toLowerCase().contains(query) ||
                    b.materialSku.toLowerCase().contains(query) ||
                    b.locationName.toLowerCase().contains(query);
                return matchesQuery;
              }).toList();

              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: 'No matching materials found',
                  description: query.isNotEmpty
                      ? 'No inventory materials match "$query".'
                      : 'Inventory catalog is currently empty.',
                  action: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Material Master'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
                      );
                    },
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final b = filtered[index];
                  final isLow = b.isLowStock;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLow ? tokens.danger.withValues(alpha: 0.6) : theme.colorScheme.outline,
                        width: isLow ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tokens.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                b.materialSku,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (isLow)
                              StatusChip(
                                label: 'LOW STOCK',
                                variant: StatusVariant.error,
                                icon: Icons.warning_amber_rounded,
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  b.locationName,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.materialName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  Text(
                                    '${b.formattedAvailable} ${b.unit}',
                                    style: TextStyle(
                                      color: b.availableQuantity > 0 ? tokens.success : tokens.danger,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Current',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  Text(
                                    '${b.formattedCurrent} ${b.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Safety Min',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  Text(
                                    '${b.formattedMinimumStock} ${b.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.history_rounded, size: 16),
                                label: const Text('Ledger'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StockHistoryScreen(
                                        initialMaterialId: b.materialId,
                                        materialName: b.materialName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.remove_circle_outline, size: 16),
                                label: const Text('Issue'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _showQuickTransactionDialog(context, b, false),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Receive'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _showQuickTransactionDialog(context, b, true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final transactionsAsync = ref.watch(stockTransactionsStreamProvider(null));

    return transactionsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading ledger audit trail...'),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Failed to load ledger: $err', style: TextStyle(color: tokens.danger)),
        ),
      ),
      data: (txList) {
        if (txList.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.receipt_long_rounded,
            title: 'No transaction ledger records yet',
            description: 'Material issues, receipts, and adjustments will appear here with cryptographic immutability.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: txList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final tx = txList[index];
            final isPositive = tx.isPositiveDelta;

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
                      StatusChip(
                        label: tx.type,
                        variant: isPositive ? StatusVariant.success : StatusVariant.error,
                        icon: isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      ),
                      const Spacer(),
                      Text(
                        tx.createdAt != null
                            ? FactoryDateUtils.formatFactoryDateTime(tx.createdAt!)
                            : 'Recent',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.materialName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'SKU: ${tx.materialSku}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tx.formattedDelta,
                            style: TextStyle(
                              color: isPositive ? tokens.success : tokens.danger,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Balance: ${tx.formattedBalanceAfter}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (tx.orderId != null && tx.orderId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Order: ${tx.orderId}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                  if (tx.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      tx.notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const Divider(height: 20),
                  Row(
                    children: [
                      Icon(Icons.person_pin_circle_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'By ${tx.performedByName}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tx.transactionNumber,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
