import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

/// Screen for raising a new shop-floor query / maintenance ticket.
class RaiseQueryScreen extends ConsumerStatefulWidget {
  final String? initialWorkOrder;
  final String? initialStage;

  const RaiseQueryScreen({
    super.key,
    this.initialWorkOrder,
    this.initialStage,
  });

  @override
  ConsumerState<RaiseQueryScreen> createState() => _RaiseQueryScreenState();
}

class _RaiseQueryScreenState extends ConsumerState<RaiseQueryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _woController = TextEditingController();
  final _stageController = TextEditingController();

  String _severity = 'medium';
  bool _isSubmitting = false;

  final List<String> _severities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkOrder != null) {
      _woController.text = widget.initialWorkOrder!;
    }
    if (widget.initialStage != null) {
      _stageController.text = widget.initialStage!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _woController.dispose();
    _stageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;

    setState(() => _isSubmitting = true);

    final ticketNumber = 'TK-${DateTime.now().year}-${(100 + (DateTime.now().millisecond % 900))}';

    final query = ProcessQuery(
      id: '',
      ticketNumber: ticketNumber,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      workOrder: _woController.text.trim(),
      stage: _stageController.text.trim(),
      severity: _severity,
      status: 'open',
      reportedByName: user?.fullName ?? 'Operator',
      reportedByUid: user?.uid ?? '',
    );

    try {
      await ref.read(queryRepositoryProvider).createQuery(orgId, query);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ticket $ticketNumber raised successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to raise ticket: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(productionOrdersStreamProvider);
    final orders = ordersAsync.value ?? [];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Raise Shop-Floor Ticket'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Issue Title *',
                  hintText: 'e.g. Laser cutting head temperature spike',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(
                  labelText: 'Severity / Priority *',
                  prefixIcon: Icon(Icons.priority_high_rounded),
                ),
                items: _severities.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _severity = val);
                },
              ),
              const SizedBox(height: 14),
              if (orders.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _woController.text.isNotEmpty && orders.any((o) => o.orderNumber == _woController.text)
                      ? _woController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Linked Work Order',
                    prefixIcon: Icon(Icons.precision_manufacturing_rounded),
                  ),
                  hint: const Text('Select active work order (Optional)'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None / General Maintenance')),
                    ...orders.map((o) => DropdownMenuItem(
                          value: o.orderNumber,
                          child: Text('${o.orderNumber} (${o.productName})'),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _woController.text = val);
                  },
                )
              else
                TextFormField(
                  controller: _woController,
                  decoration: const InputDecoration(
                    labelText: 'Linked Work Order # (Optional)',
                    hintText: 'e.g. WO-2026-101',
                    prefixIcon: Icon(Icons.precision_manufacturing_rounded),
                  ),
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stageController,
                decoration: const InputDecoration(
                  labelText: 'Manufacturing Stage / Station',
                  hintText: 'e.g. 3D Precision Machining',
                  prefixIcon: Icon(Icons.engineering_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detailed Problem Description *',
                  hintText: 'Describe machine alarms, dimensional drift, material defect, or drawings ambiguity...',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Raising Ticket...' : 'Submit Ticket'),
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
