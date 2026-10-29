import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/core/widgets/responsive_layout.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';
import 'package:unity/features/processes/presentation/widgets/unity_process_flow_chart_widget.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/process_task_card.dart';

class ProcessListScreen extends ConsumerStatefulWidget {
  const ProcessListScreen({super.key});

  @override
  ConsumerState<ProcessListScreen> createState() => _ProcessListScreenState();
}

class _ProcessListScreenState extends ConsumerState<ProcessListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStage = 'All';

  final List<String> _stages = [
    'All',
    'RFQ',
    'FEASIBILITY STUDY',
    'QUOTE',
    'PURCHASE ORDER',
    'CONCEPT DWG DESIGN',
    'DESIGNING 3D MODELING',
    'BOM RELEASE',
    'MATERIAL PROCUREMENT',
    'DETAIL DWG RELEASE',
    'ROUGH MACHINING',
    '3D PRECISION MACHINING',
    'HEAT TREATMENT',
    '2D PRECISION MACHINING',
    'ASSEMBLY',
    'TRAIL',
    'INSPECTION',
    'DISPATCH',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showDispatchTaskDialog(BuildContext context, String orgId, [String? initialStage]) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController();
    final woController = TextEditingController(text: 'WO-2026-081');
    final notesController = TextEditingController();

    String selectedStage = initialStage ?? 'ROUGH MACHINING';
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                const Expanded(
                  child: Text(
                    'Dispatch Process Task',
                    style: AppTextStyles.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
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
                            isExpanded: true,
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
                              if (v != null) {
                                setDialogState(() {
                                  woController.text = v;
                                });
                              }
                            },
                          )
                        else
                          TextFormField(
                            controller: woController,
                            decoration: const InputDecoration(
                              labelText: 'Work Order # *',
                              hintText: 'e.g. WO-2026-081',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Work Order is required' : null,
                          ),
                        const SizedBox(height: 12),

                        // Task Title
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Task Title *',
                            hintText: 'e.g. Execute Rough Machining for Bracket Batch',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Task title is required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Process Stage Selector (17 Unity Engineers Stages)
                        DropdownButtonFormField<String>(
                          initialValue: selectedStage,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Process Stage (17 Stages)',
                            border: OutlineInputBorder(),
                          ),
                          items: _stages
                              .where((s) => s != 'All')
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedStage = v);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Assigned Employee Selector
                        DropdownButtonFormField<String>(
                          initialValue: selectedEmployeeUid,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assign Operator / Employee',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Unassigned (Shop-Floor Team)', overflow: TextOverflow.ellipsis),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Unassigned (Shop-Floor Team)', overflow: TextOverflow.ellipsis),
                            ),
                            ...employees.map((emp) {
                              return DropdownMenuItem(
                                value: emp.uid,
                                child: Text('${emp.fullName} (${emp.role.value})', overflow: TextOverflow.ellipsis),
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

                        // Priority and Status
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedPriority,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'normal', child: Text('Normal', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'high', child: Text('High', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'urgent', child: Text('Urgent', overflow: TextOverflow.ellipsis)),
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
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'pending', child: Text('Pending', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress', overflow: TextOverflow.ellipsis)),
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
                          hintText: 'e.g. Verify tolerances +/- 0.05mm as per Detail DWG',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
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

                        final newTask = ProcessTask(
                          id: '',
                          title: titleController.text.trim(),
                          stage: selectedStage,
                          workOrder: woController.text.trim(),
                          priority: selectedPriority,
                          status: selectedStatus,
                          assignedToUid: selectedEmployeeUid ?? '',
                          assignedToName: selectedEmployeeName,
                          scheduledDate: DateTime.now(),
                          notes: notesController.text.trim(),
                          updatedAt: DateTime.now(),
                        );

                        try {
                          await ref.read(taskRepositoryProvider).createTask(orgId, newTask);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Dispatched task for $selectedStage'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.schema_rounded), text: 'Flow Chart Plan (17 Stages)'),
            Tab(icon: Icon(Icons.task_alt_rounded), text: 'Floor Stage Tasks'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDispatchTaskDialog(context, orgId),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Dispatch Task'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ResponsiveContainer(
        padding: EdgeInsets.zero,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Visual Process Flow Chart Plan
            _buildFlowChartPlanTab(context, orgId),

            // Tab 2: Live Floor Tasks
            _buildFloorTasksTab(tasksAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowChartPlanTab(BuildContext context, String orgId) {
    final stages = ProcessTemplateModel.default17Stages();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Official High-Fidelity Flow Chart
          UnityProcessFlowChartWidget(
            showHeader: true,
            onStageTap: (seq, name) {
              _showDispatchTaskDialog(context, orgId, name);
            },
          ),
          const SizedBox(height: 24),

          // Sequential Stages Breakdown Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Process Stage Specifications (17 Steps)',
                      style: AppTextStyles.titleMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Standard Operating Procedure',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stages.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderSubtle),
                  itemBuilder: (context, index) {
                    final stage = stages[index];
                    final depText = stage.dependsOnStepSequence.isEmpty
                        ? 'Initiation stage'
                        : 'Requires Step ${stage.dependsOnStepSequence.join(", ")}';

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          '${stage.sequence}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        stage.name,
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$depText • Std: ${stage.defaultDurationHours}h',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Dispatch'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _showDispatchTaskDialog(context, orgId, stage.name),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFloorTasksTab(AsyncValue<List<ProcessTask>> tasksAsync) {
    return tasksAsync.when(
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
                    color: AppColors.error,
                    icon: Icons.pause_circle_outline_rounded,
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
                  hintText: 'Search by Task, Work Order, or Operator...',
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

              // 17-Stage Filter Chips Carousel
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _stages.map((stage) {
                    final isSelected = _selectedStage == stage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(stage, style: const TextStyle(fontSize: 11)),
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _selectedStage = val ? stage : 'All';
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Task Cards List
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.schema_outlined, size: 48, color: AppColors.textMuted),
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
                  ),
                )
              else
                ...filtered.map((task) => ProcessTaskCard(task: task)),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
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
