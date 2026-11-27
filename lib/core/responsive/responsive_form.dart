import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Layout utility for organizing form fields responsively:
/// - Desktop: Multiple columns (2 to 4).
/// - Tablet: 2 columns.
/// - Mobile: Single column.
///
/// Ensures inputs resize cleanly without horizontal clipping or overflow.
class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveFormRow({
    super.key,
    required this.children,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: runSpacing),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}

/// A responsive, keyboard-aware scrollable container for data-entry forms.
class ResponsiveFormContainer extends StatelessWidget {
  final Widget child;
  final GlobalKey<FormState>? formKey;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.formKey,
    this.maxWidth = 900.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 24.0,
          vertical: isMobile ? 16.0 : 24.0,
        );

    final formWidget = formKey != null ? Form(key: formKey, child: child) : child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: effectivePadding,
          physics: const ClampingScrollPhysics(),
          child: formWidget,
        ),
      ),
    );
  }
}
