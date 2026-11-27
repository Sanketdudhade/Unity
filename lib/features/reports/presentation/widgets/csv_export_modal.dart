import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/file_downloader.dart';

/// Modal dialog previewing and copying/downloading generated CSV data.
class CsvExportModal extends StatelessWidget {
  final String title;
  final String filename;
  final String csvContent;
  final int recordCount;

  const CsvExportModal({
    super.key,
    required this.title,
    required this.filename,
    required this.csvContent,
    required this.recordCount,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String filename,
    required String csvContent,
    required int recordCount,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CsvExportModal(
        title: title,
        filename: filename,
        csvContent: csvContent,
        recordCount: recordCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.table_view_rounded, color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Text('$recordCount records ready for export', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      filename,
                      style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('CSV Preview (First 500 characters):', style: AppTextStyles.labelSmall),
            const SizedBox(height: 6),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csvContent.length > 500 ? '${csvContent.substring(0, 500)}...\n[Truncated for preview]' : csvContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 14),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: csvContent));
            if (context.mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Copied $recordCount CSV rows to clipboard!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: () async {
            final result = await downloadFile(
              filename: filename,
              content: csvContent,
            );
            if (context.mounted) {
              Navigator.pop(context);
              if (result.success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Downloaded $filename to Downloads folder!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    action: result.filePath != null
                        ? SnackBarAction(
                            label: 'Show in Folder',
                            textColor: Colors.white,
                            onPressed: () => openDownloadedFile(result.filePath!),
                          )
                        : null,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result.message ?? 'Failed to download CSV.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
