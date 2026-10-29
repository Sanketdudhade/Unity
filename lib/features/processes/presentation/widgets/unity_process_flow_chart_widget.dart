import 'package:flutter/material.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/features/processes/data/models/process_step_model.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';

/// Interactive, high-fidelity visual rendering of the official:
/// UNITY ENGINEERS - PROCESS FLOW CHART PLAN (17 Stages)
class UnityProcessFlowChartWidget extends StatelessWidget {
  /// Optional list of live order stages to display live execution status
  final List<OrderProcessModel>? liveOrderStages;

  /// Optional callback when a stage node is tapped
  final void Function(int sequence, String name)? onStageTap;

  /// Optional callback when assign employee is triggered for a stage
  final void Function(int sequence, String name, OrderProcessModel? liveStage)? onAssignEmployee;

  /// Optional callback to open mass stage assignment dialog
  final VoidCallback? onAssignAllStages;

  /// Whether current user is admin / can assign employees
  final bool canAssign;

  /// Whether to display the full company header
  final bool showHeader;

  const UnityProcessFlowChartWidget({
    super.key,
    this.liveOrderStages,
    this.onStageTap,
    this.onAssignEmployee,
    this.onAssignAllStages,
    this.canAssign = false,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final stages = ProcessTemplateModel.default17Stages();
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showHeader) ...[
            _buildCompanyHeader(),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
          ],
          _buildStatusLegend(stages),
          const SizedBox(height: 20),
          if (isDesktop)
            _buildDesktopSerpentineFlow(context, stages)
          else
            _buildMobileAdaptiveFlow(context, stages),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(List<ProcessStepModel> stages) {
    int doneCount = 0;
    int workingCount = 0;
    int pendingCount = 0;

    if (liveOrderStages != null) {
      for (final s in liveOrderStages!) {
        final status = s.status.toUpperCase();
        if (status == 'COMPLETED') {
          doneCount++;
        } else if (status == 'IN_PROGRESS' ||
            status == 'PENDING_APPROVAL' ||
            status == 'REWORK_REQUIRED') {
          workingCount++;
        } else {
          pendingCount++;
        }
      }
    } else {
      pendingCount = stages.length;
    }

    final legendWrap = Wrap(
      spacing: 20,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildLegendItem(
          color: const Color(0xFF64748B),
          label: 'Pending',
          count: liveOrderStages != null ? pendingCount : null,
          icon: Icons.radio_button_unchecked_rounded,
        ),
        _buildLegendItem(
          color: const Color(0xFFD97706),
          label: 'Working',
          count: liveOrderStages != null ? workingCount : null,
          icon: Icons.sync_rounded,
        ),
        _buildLegendItem(
          color: const Color(0xFF16A34A),
          label: 'Done',
          count: liveOrderStages != null ? doneCount : null,
          icon: Icons.check_circle_rounded,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: canAssign && onAssignAllStages != null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Align(alignment: Alignment.centerLeft, child: legendWrap)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.assignment_ind_outlined, size: 14),
                  label: const Text('Assign Stages'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: onAssignAllStages,
                ),
              ],
            )
          : Center(child: legendWrap),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    int? count,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompanyHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.precision_manufacturing_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'UNITY ENGINEERS',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: Color(0xFF0D47A1),
                fontFamily: 'serif',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'B-15/2/61, MIDC, WALUJ, AURANGABAD, M.H. INDIA. 431136',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 2,
              width: 32,
              color: const Color(0xFFD32F2F),
            ),
            const SizedBox(width: 8),
            const Text(
              'PROCESS FLOW CHART PLAN:-',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFFD32F2F),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 2,
              width: 32,
              color: const Color(0xFFD32F2F),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the 3-row serpentine flow matching the company's chart
  Widget _buildDesktopSerpentineFlow(
    BuildContext context,
    List<ProcessStepModel> stages,
  ) {
    // Row 1: Steps 1 to 6 (left to right)
    final row1 = stages.sublist(0, 6);
    // Row 2: Steps 7 to 12 (right to left)
    final row2 = stages.sublist(6, 12);
    // Row 3: Steps 13 to 17 (left to right)
    final row3 = stages.sublist(12, 17);

    return Column(
      children: [
        // Row 1
        _buildRow(row1, isReversed: false),
        _buildVerticalConnector(alignRight: true),

        // Row 2
        _buildRow(row2, isReversed: true),
        _buildVerticalConnector(alignRight: false),

        // Row 3
        _buildRow(row3, isReversed: false, fillEmptySlots: 1),
      ],
    );
  }

  Widget _buildRow(
    List<ProcessStepModel> steps, {
    required bool isReversed,
    int fillEmptySlots = 0,
  }) {
    final displaySteps = isReversed ? steps.reversed.toList() : steps;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = 0; i < displaySteps.length; i++) ...[
          Expanded(
            child: _buildStageNode(displaySteps[i]),
          ),
          if (i < displaySteps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(
                isReversed ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 20,
                color: const Color(0xFF78909C),
              ),
            ),
        ],
        for (int i = 0; i < fillEmptySlots; i++) ...[
          const SizedBox(width: 28),
          const Spacer(),
        ],
      ],
    );
  }

  Widget _buildVerticalConnector({required bool alignRight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_downward_rounded,
            size: 22,
            color: Color(0xFF455A64),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAdaptiveFlow(
    BuildContext context,
    List<ProcessStepModel> stages,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            for (int i = 0; i < stages.length; i++) ...[
              SizedBox(
                width: 150,
                child: _buildStageNode(stages[i]),
              ),
              if (i < stages.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Color(0xFF78909C),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStageNode(ProcessStepModel step) {
    final liveStage = liveOrderStages?.firstWhere(
      (s) => s.sequence == step.sequence,
      orElse: () => OrderProcessModel(
        id: '',
        templateStepId: step.id,
        name: step.name,
        sequence: step.sequence,
        targetQty: 0,
      ),
    );

    final isLive = liveOrderStages != null;
    final status = (liveStage?.status ?? 'NOT_STARTED').toUpperCase();
    final isDone = isLive && status == 'COMPLETED';
    final isWorking = isLive &&
        (status == 'IN_PROGRESS' ||
            status == 'PENDING_APPROVAL' ||
            status == 'REWORK_REQUIRED');

    // Exactly 3 colors for the flow:
    // 1. Pending -> Slate Grey
    // 2. Working -> Amber / Safety Orange
    // 3. Done    -> Emerald Green
    final List<Color> gradientColors;
    final Color borderColor;
    final double borderWidth;
    final Color shadowColor;
    final IconData statusIcon;
    final String statusLabel;

    if (isDone) {
      gradientColors = const [Color(0xFF15803D), Color(0xFF22C55E)]; // Done (Green)
      borderColor = const Color(0xFF86EFAC).withValues(alpha: 0.6);
      borderWidth = 1.0;
      shadowColor = const Color(0xFF15803D).withValues(alpha: 0.35);
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Done';
    } else if (isWorking) {
      gradientColors = const [Color(0xFFD97706), Color(0xFFF59E0B)]; // Working (Amber / Orange)
      borderColor = const Color(0xFFFDE68A);
      borderWidth = 2.0;
      shadowColor = const Color(0xFFD97706).withValues(alpha: 0.45);
      statusIcon = Icons.sync_rounded;
      statusLabel = 'Working';
    } else {
      gradientColors = const [Color(0xFF64748B), Color(0xFF475569)]; // Pending (Slate Grey)
      borderColor = const Color(0xFF94A3B8).withValues(alpha: 0.4);
      borderWidth = 1.0;
      shadowColor = const Color(0xFF334155).withValues(alpha: 0.25);
      statusIcon = Icons.radio_button_unchecked_rounded;
      statusLabel = 'Pending';
    }

    final assignedName = (liveStage != null &&
            liveStage.assignedEmployeeName.isNotEmpty &&
            liveStage.assignedEmployeeName != 'Unassigned')
        ? liveStage.assignedEmployeeName
        : 'Unassigned';

    return Tooltip(
      message: 'Step ${step.sequence}: ${step.name} ($statusLabel) • Operator: $assignedName',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onAssignEmployee != null) {
              onAssignEmployee!(step.sequence, step.name, liveStage);
            } else {
              onStageTap?.call(step.sequence, step.name);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: isWorking ? 8 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${step.sequence}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      statusIcon,
                      size: 13,
                      color: isWorking ? Colors.yellowAccent : Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  step.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (liveStage != null && liveStage.assignedEmployeeUid.isNotEmpty)
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        size: 9,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          assignedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
