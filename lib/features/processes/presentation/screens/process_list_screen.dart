import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/process_task_card.dart';

class ProcessListScreen extends ConsumerStatefulWidget {
  const ProcessListScreen({super.key});

  @override
  ConsumerState<ProcessListScreen> createState() => _ProcessListScreenState();
}

class _ProcessListScreenState extends ConsumerState<ProcessListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStage = 'All';

  final List<String> _stages = [
    'All',
    'Cutting & Forming',
    'Machining',
    'Welding',
    'Assembly',
    'Inspection',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDispatchTaskDialog(BuildContext context, String orgId) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController();
    final woController = TextEditingController(text: 'WO-2026-081');
    final notesController = TextEditingController();

    String selectedStage = 'Cutting & Forming';
    String selectedPriority = 'normal';
    String selectedStatus = 'pending';
    String? selectedEmployeeUid;
    String selectedEmployeeName = 'Shop-Floor Team';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final employees = ref.watch(employeesStreamProvider).value ?? [];
          final orders = ref.watch(productionOrdersStreamProvider).value ?? [];

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_add_rounded, color: AppColors.secondary, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Dispatch Process Task', style: AppTextStyles.titleMedium),
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
                      // Work Order Selector
                      if (orders.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: orders.any((o) => o.orderNumber == woController.text)
                              ? woController.text
                              : orders.first.orderNumber,
                          decoration: const InputDecoration(
                            labelText: 'Work Order *',
                            border: OutlineInputBorder(),
                          ),
                          items: orders.map((o) {
                            return DropdownMenuItem(
                              value: o.orderNumber,
                              child: Text('${o.orderNumber} - ${o.productName}', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) woController.text = v;
                          },
                        )
                      else
                        TextFormField(
                          controller: woController,
                          decoration: const InputDecoration(
                            labelText: 'Work Order *',
                            hintText: 'e.g. WO-2026-081',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Task / Operation Title *',
                          hintText: 'e.g. CNC Lathe Turning: Flange Inner Ring',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: selectedStage,
                        decoration: const InputDecoration(
                          labelText: 'Process Stage',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cutting & Forming', child: Text('Cutting & Forming')),
                          DropdownMenuItem(value: 'Machining', child: Text('CNC Machining')),
                          DropdownMenuItem(value: 'Welding', child: Text('Welding & Fabrication')),
                          DropdownMenuItem(value: 'Assembly', child: Text('Assembly')),
                          DropdownMenuItem(value: 'Inspection', child: Text('Inspection & QA')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedStage = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Assigned Employee Selector
                      DropdownButtonFormField<String>(
                        initialValue: selectedEmployeeUid,
                        decoration: const InputDecoration(
                          labelText: 'Assign Operator / Employee',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Unassigned (Shop-Floor Team)'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Unassigned (Shop-Floor Team)'),
                          ),
                          ...employees.map((emp) {
                            return DropdownMenuItem(
                              value: emp.uid,
                              child: Text('${emp.fullName} (${emp.role.value})'),
                            );
                          }),
                        ],
                        onChanged: (uid) {
                          setDialogState(() {
                            selectedEmployeeUid = uid;
                            if (uid != null) {
                              final match = employees.firstWhere((e) => e.uid == uid);
                              selectedEmployeeName = match.fullName;
                            } else {
                              selectedEmployeeName = 'Shop-Floor Team';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedPriority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                DropdownMenuItem(value: 'high', child: Text('High')),
                                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedPriority = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedStatus = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Operator Instructions / Tolerances',
                          hintText: 'e.g. Clean edges, verify dimension +/- 0.05mm',
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

                        final task = ProcessTask(
                          id: '',
                          title: titleController.text.trim(),
                          stage: selectedStage,
                          workOrder: woController.text.trim(),
                          assignedToUid: selectedEmployeeUid ?? '',
                          assignedToName: selectedEmployeeName,
                          status: selectedStatus,
                          priority: selectedPriority,
                          scheduledDate: DateTime.now(),
                          notes: notesController.text.trim(),
                        );

                        try {
                          await ref.read(taskRepositoryProvider).createTask(orgId, task);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Dispatched task [${task.workOrder}] to $selectedEmployeeName'),
                                backgroundColor: AppColors.secondary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to dispatch task: $e'),
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
                    : const Text('Dispatch Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Processes & Workflows'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDispatchTaskDialog(context, orgId),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Dispatch Task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: tasksAsync.when(
        loading: () => const LoadingWidget(message: 'Loading process tasks...'),
        error: (err, _) => Center(
          child: Text('Error loading tasks: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (tasks) {
          final query = _searchController.text.trim().toLowerCase();
          final filtered = tasks.where((t) {
            final matchesStage = _selectedStage == 'All' ||
                t.stage.toLowerCase().contains(_selectedStage.toLowerCase());

            final matchesQuery = query.isEmpty ||
                t.title.toLowerCase().contains(query) ||
                t.workOrder.toLowerCase().contains(query) ||
                t.assignedToName.toLowerCase().contains(query);

            return matchesStage && matchesQuery;
          }).toList();

          final inProgCount = tasks.where((t) => t.isInProgress).length;
          final pausedCount = tasks.where((t) => t.isPaused).length;
          final pendingCount = tasks.where((t) => t.isPending).length;
          final completedCount = tasks.where((t) => t.isCompleted).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tasksStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Metric Overview Row
                Row(
                  children: [
                    _MiniStatusCard(
                      label: 'In Progress',
                      count: inProgCount,
                      color: AppColors.info,
                      icon: Icons.play_arrow_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatusCard(
                      label: 'Pending',
                      count: pendingCount,
                      color: AppColors.warning,
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatusCard(
                      label: 'Paused',
                      count: pausedCount,
                      color: AppColors.accent,
                      icon: Icons.pause_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatusCard(
                      label: 'Completed',
                      count: completedCount,
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Title, Work Order, or Operator...',
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

                // Stage Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _stages.map((stage) {
                      final isSelected = _selectedStage == stage;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(stage),
                          selectedColor: AppColors.primaryLight,
                          labelStyle: AppTextStyles.labelSmall.copyWith(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _selectedStage = stage),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.schema_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          tasks.isEmpty
                              ? 'No process stages active.\nTap "Dispatch Task" below to assign work.'
                              : 'No process tasks match your filter criteria.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((task) => ProcessTaskCard(task: task)),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStatusCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniStatusCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
