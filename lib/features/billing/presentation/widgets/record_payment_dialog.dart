import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/invoice_payment_model.dart';
import '../../data/services/indian_currency_formatter.dart';
import '../providers/billing_providers.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final InvoiceModel invoice;
  final String userId;

  const RecordPaymentDialog({
    super.key,
    required this.invoice,
    required this.userId,
  });

  static Future<void> show(
    BuildContext context, {
    required InvoiceModel invoice,
    required String userId,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => RecordPaymentDialog(invoice: invoice, userId: userId),
    );
  }

  @override
  ConsumerState<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountCtrl;
  late TextEditingController _referenceCtrl;
  late TextEditingController _notesCtrl;

  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'Bank Transfer';
  bool _isSaving = false;

  final List<String> _methods = [
    'Bank Transfer',
    'NEFT / RTGS',
    'UPI',
    'Cheque',
    'Cash',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.invoice.outstandingAmount > 0
          ? widget.invoice.outstandingAmount.toStringAsFixed(2)
          : '0.00',
    );
    _referenceCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payment = InvoicePaymentModel(
        id: '',
        invoiceId: widget.invoice.id,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMethod: _paymentMethod,
        transactionReference: _referenceCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        recordedBy: widget.userId,
      );

      final repo = ref.read(billingRepositoryProvider);
      await repo.recordPayment(
        invoiceId: widget.invoice.id,
        payment: payment,
        userId: widget.userId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${IndianCurrencyFormatter.format(amount)} recorded successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.invoice.outstandingAmount;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenWidth < 450;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: min(640.0, screenHeight - 32),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Record Payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 18 : 20,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  'Invoice: ${widget.invoice.invoiceNumber} • Outstanding: ${IndianCurrencyFormatter.format(outstanding)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (₹) *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final parsed = double.tryParse(v);
                    if (parsed == null || parsed <= 0) return 'Invalid amount';
                    if (parsed > outstanding + 0.05) {
                      return 'Amount exceeds outstanding balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (isCompact) ...[
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _methods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _paymentDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Payment Date',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(
                        '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _methods
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentMethod = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _paymentDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Payment Date',
                              border: OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: Icon(Icons.calendar_today, size: 16),
                            ),
                            child: Text(
                              '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Ref / UTR / Cheque No.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Confirm Payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
