import 'dart:math';
import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Reusable responsive dialog container that prevents screen overflow,
/// adapts gracefully to small phone viewports and large desktop monitors,
/// and stays within viewport bounds even when the virtual keyboard is open.
class ResponsiveDialog extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry? contentPadding;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final bool scrollable;

  const ResponsiveDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.maxWidth = 640.0,
    this.maxHeight = 750.0,
    this.insetPadding,
    this.contentPadding,
    this.shape,
    this.backgroundColor,
    this.scrollable = true,
  });

  /// Static helper to display this responsive dialog.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final effectiveMaxWidth = min(maxWidth, max(280.0, screenWidth - (isMobile ? 24.0 : 48.0)));
    final effectiveMaxHeight = min(maxHeight, max(300.0, screenHeight - (isMobile ? 32.0 : 64.0)));

    final effectiveInsetPadding = insetPadding ??
        EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 24.0,
          vertical: isMobile ? 16.0 : 24.0,
        );

    Widget dialogContent = content;
    if (scrollable) {
      dialogContent = SingleChildScrollView(
        child: content,
      );
    }

    return Dialog(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      insetPadding: effectiveInsetPadding,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 12.0 : 16.0),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: effectiveMaxWidth,
          maxHeight: effectiveMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16.0 : 20.0,
                  isMobile ? 16.0 : 20.0,
                  isMobile ? 16.0 : 20.0,
                  12.0,
                ),
                child: DefaultTextStyle(
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 17.0 : 19.0,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  child: title!,
                ),
              ),
              const Divider(height: 1),
            ],
            Flexible(
              child: Padding(
                padding: contentPadding ??
                    EdgeInsets.all(isMobile ? 16.0 : 20.0),
                child: dialogContent,
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12.0 : 16.0,
                  vertical: isMobile ? 8.0 : 12.0,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: actions!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
