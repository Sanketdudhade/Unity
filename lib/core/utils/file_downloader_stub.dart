class DownloadResult {
  final bool success;
  final String? filePath;
  final String? message;

  const DownloadResult({
    required this.success,
    this.filePath,
    this.message,
  });
}

Future<DownloadResult> downloadFile({
  required String filename,
  required String content,
}) async {
  return const DownloadResult(
    success: false,
    message: 'File download is not supported on this platform.',
  );
}

Future<void> openDownloadedFile(String filePath) async {}
