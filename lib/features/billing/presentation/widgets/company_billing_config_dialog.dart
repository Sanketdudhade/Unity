import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/company_billing_config_model.dart';
import '../providers/billing_providers.dart';

class CompanyBillingConfigDialog extends ConsumerStatefulWidget {
  final CompanyBillingConfigModel initialConfig;

  const CompanyBillingConfigDialog({
    super.key,
    required this.initialConfig,
  });

  static Future<void> show(BuildContext context, CompanyBillingConfigModel config) {
    return showDialog(
      context: context,
      builder: (ctx) => CompanyBillingConfigDialog(initialConfig: config),
    );
  }

  @override
  ConsumerState<CompanyBillingConfigDialog> createState() =>
      _CompanyBillingConfigDialogState();
}

class _CompanyBillingConfigDialogState
    extends ConsumerState<CompanyBillingConfigDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _stateCodeCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _panCtrl;

  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountHolderCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _declarationCtrl;
  late TextEditingController _signatoryCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _nameCtrl = TextEditingController(text: c.companyName);
    _addressCtrl = TextEditingController(text: c.registeredAddress);
    _gstinCtrl = TextEditingController(text: c.gstin);
    _stateCtrl = TextEditingController(text: c.state);
    _stateCodeCtrl = TextEditingController(text: c.stateCode);
    _emailCtrl = TextEditingController(text: c.email);
    _panCtrl = TextEditingController(text: c.pan);

    _bankNameCtrl = TextEditingController(text: c.bankName);
    _accountHolderCtrl = TextEditingController(text: c.accountHolderName);
    _accountNumberCtrl = TextEditingController(text: c.accountNumber);
    _branchCtrl = TextEditingController(text: c.branch);
    _ifscCtrl = TextEditingController(text: c.ifscCode);
    _declarationCtrl = TextEditingController(text: c.declaration);
    _signatoryCtrl = TextEditingController(text: c.authorisedSignatory);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _gstinCtrl.dispose();
    _stateCtrl.dispose();
    _stateCodeCtrl.dispose();
    _emailCtrl.dispose();
    _panCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountHolderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _branchCtrl.dispose();
    _ifscCtrl.dispose();
    _declarationCtrl.dispose();
    _signatoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updated = widget.initialConfig.copyWith(
        companyName: _nameCtrl.text.trim(),
        registeredAddress: _addressCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim().toUpperCase(),
        state: _stateCtrl.text.trim(),
        stateCode: _stateCodeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        pan: _panCtrl.text.trim().toUpperCase(),
        bankName: _bankNameCtrl.text.trim(),
        accountHolderName: _accountHolderCtrl.text.trim(),
        accountNumber: _accountNumberCtrl.text.trim(),
        branch: _branchCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        declaration: _declarationCtrl.text.trim(),
        authorisedSignatory: _signatoryCtrl.text.trim(),
      );

      final repo = ref.read(billingRepositoryProvider);
      await repo.saveCompanyBillingConfig(updated);
      ref.invalidate(companyBillingConfigProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company billing settings updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: min(800.0, size.height - 32.0),
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Company & Bank Profile Configuration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Company Information',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Company Name *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Registered Address *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _gstinCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'GSTIN *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _panCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'PAN *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isCompact) ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _stateCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'State *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _stateCodeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'State Code *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _stateCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'State *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _stateCodeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'State Code *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _emailCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          'Bank Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        if (size.width < 450) ...[
                          TextFormField(
                            controller: _bankNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Bank Name *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _branchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Branch *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _bankNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Bank Name *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _branchCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Branch *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        if (size.width < 450) ...[
                          TextFormField(
                            controller: _accountNumberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Account Number *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _ifscCtrl,
                            decoration: const InputDecoration(
                              labelText: 'IFSC Code *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _accountNumberCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Account Number *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _ifscCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'IFSC Code *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          'Signatory & Statutory Declaration',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _signatoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Authorised Signatory *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _declarationCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Declaration Text',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Profile'),
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
