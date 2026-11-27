import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Reusable table widget that supports responsive presentation:
/// - Desktop & Tablet: Full horizontal DataTable with flexible columns.
/// - Mobile (< 600 px): Structured card list or horizontally scrollable table
///   ensuring all action buttons and statuses remain easily accessible.
class ResponsiveTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool isMobileCardView;
  final Widget Function(BuildContext context, int index)? mobileCardBuilder;
  final Widget? emptyState;
  final EdgeInsetsGeometry padding;

  const ResponsiveTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isMobileCardView = false,
    this.mobileCardBuilder,
    this.emptyState,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return emptyState ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No records to display.'),
            ),
          );
    }

    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Mobile card view if enabled and builder provided
    if (isMobile && isMobileCardView && mobileCardBuilder != null) {
      return ListView.separated(
        padding: padding,
        itemCount: rows.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: 8.0),
        itemBuilder: (ctx, i) => mobileCardBuilder!(ctx, i),
      );
    }

    // Default: horizontally scrollable high-density tabular view
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 32.0,
        ),
        child: DataTable(
          columns: columns,
          rows: rows,
          horizontalMargin: isMobile ? 12.0 : 20.0,
          columnSpacing: isMobile ? 14.0 : 24.0,
          headingRowHeight: isMobile ? 42.0 : 48.0,
          dataRowMinHeight: isMobile ? 44.0 : 52.0,
          dataRowMaxHeight: isMobile ? 58.0 : 68.0,
        ),
      ),
    );
  }
}

/// A structured card item for displaying tabular rows on mobile screens.
class ResponsiveDataCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? status;
  final List<Widget> details;
  final List<Widget>? actions;
  final VoidCallback? onTap;

  const ResponsiveDataCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.status,
    this.details = const [],
    this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 10.0),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        if (subtitle != null) ...[
                          const SizedBox(height: 2.0),
                          subtitle!,
                        ],
                      ],
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 8.0),
                    status!,
                  ],
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 10.0),
                ...details,
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                const Divider(height: 16.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
