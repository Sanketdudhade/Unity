import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/inventory/presentation/screens/add_material_screen.dart';
import 'package:unity/features/inventory/presentation/screens/low_stock_screen.dart';
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickTransactionDialog(BuildContext context, StockBalanceModel balance, bool isReceipt) {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;

    final qtyController = TextEditingController(text: isReceipt ? '50' : '10');
    final refController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReceipt ? 'Receive Stock (GRN)' : 'Issue Material to Floor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${balance.materialName} (${balance.materialSku})', style: AppTextStyles.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Available Stock: ${balance.formattedAvailable} ${balance.unit}',
              style: AppTextStyles.bodySmall.copyWith(
                color: balance.availableQuantity > 0 ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w600,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReceipt ? AppColors.success : AppColors.warning,
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
                    backgroundColor: isReceipt ? AppColors.success : AppColors.secondary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Transaction failed: $e'),
                    backgroundColor: AppColors.error,
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
    final balancesAsync = ref.watch(stockBalancesStreamProvider);
    final lowStockAsync = ref.watch(lowStockBalancesStreamProvider);
    final lowStockCount = lowStockAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory & Material Master'),
        actions: [
          IconButton(
            tooltip: 'View Reorder Alerts',
            icon: Badge(
              isLabelVisible: lowStockCount > 0,
              label: Text('$lowStockCount'),
              child: const Icon(Icons.notifications_active_outlined),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LowStockScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Add Material Master',
            icon: const Icon(Icons.add_box_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Materials & Stock'),
            const Tab(text: 'Transaction Ledger'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Low Stock'),
                  if (lowStockCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Materials & Stock Tab
          _buildMaterialsListTab(balancesAsync),

          // 2. Authoritative Transaction Ledger Tab
          _buildLedgerTab(),

          // 3. Low Stock Tab
          const LowStockScreen(),
        ],
      ),
    );
  }

  Widget _buildMaterialsListTab(AsyncValue<List<StockBalanceModel>> balancesAsync) {
    return Column(
      children: [
        // Search & Category Filters
        Container(
          padding: const EdgeInsets.all(16.0),
          color: AppColors.surface,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search SKU, material name, or location...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
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
              child: Text('Failed to load inventory: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
            ),
            data: (balances) {
              final query = _searchController.text.toLowerCase().trim();
              final filtered = balances.where((b) {
                final matchesQuery = b.materialName.toLowerCase().contains(query) ||
                    b.materialSku.toLowerCase().contains(query) ||
                    b.locationName.toLowerCase().contains(query);
                return matchesQuery;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.border),
                      const SizedBox(height: 12),
                      Text('No matching materials found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Material Master'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final b = filtered[index];
                  final isLow = b.isLowStock;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isLow ? AppColors.error.withValues(alpha: 0.6) : AppColors.border,
                        width: isLow ? 1.5 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  b.materialSku,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isLow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                                      const SizedBox(width: 2),
                                      Text(
                                        'LOW STOCK',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                b.locationName,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b.materialName,
                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Available', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                    Text(
                                      '${b.formattedAvailable} ${b.unit}',
                                      style: AppTextStyles.titleSmall.copyWith(
                                        color: b.availableQuantity > 0 ? AppColors.success : AppColors.error,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Current', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                    Text(
                                      '${b.formattedCurrent} ${b.unit}',
                                      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Safety Min', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                    Text(
                                      '${b.formattedMinimumStock} ${b.unit}',
                                      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
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
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.remove_circle_outline, size: 16),
                                label: const Text('Issue'),
                                onPressed: () => _showQuickTransactionDialog(context, b, false),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Receive'),
                                onPressed: () => _showQuickTransactionDialog(context, b, true),
                              ),
                            ],
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
    );
  }

  Widget _buildLedgerTab() {
    final transactionsAsync = ref.watch(stockTransactionsStreamProvider(null));

    return transactionsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading ledger audit trail...'),
      error: (err, _) => Center(
        child: Text('Failed to load ledger: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
      ),
      data: (txList) {
        if (txList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.border),
                const SizedBox(height: 12),
                Text('No transaction ledger records yet', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: txList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tx = txList[index];
            final isPositive = tx.isPositiveDelta;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.type,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isPositive ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          tx.createdAt != null
                              ? FactoryDateUtils.formatFactoryDateTime(tx.createdAt!)
                              : 'Recent',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
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
                              Text(tx.materialName, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                              Text('SKU: ${tx.materialSku}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tx.formattedDelta,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: isPositive ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Balance: ${tx.formattedBalanceAfter}',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (tx.orderId != null && tx.orderId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Order: ${tx.orderId}',
                          style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (tx.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        tx.notes,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_circle_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'By ${tx.performedByName}',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          tx.transactionNumber,
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
