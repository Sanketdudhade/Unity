import 'dart:io';
import 'package:flutter/foundation.dart';

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

/// Saves [content] into a file named [filename] within the user's Downloads directory.
Future<DownloadResult> downloadFile({
  required String filename,
  required String content,
}) async {
  try {
    Directory? targetDir;

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final downloads = Directory('$userProfile\\Downloads');
        if (downloads.existsSync()) {
          targetDir = downloads;
        } else {
          targetDir = Directory(userProfile);
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final downloads = Directory('$home/Downloads');
        if (downloads.existsSync()) {
          targetDir = downloads;
        } else {
          targetDir = Directory(home);
        }
      }
    } else if (Platform.isAndroid) {
      final androidDownloads = Directory('/storage/emulated/0/Download');
      if (androidDownloads.existsSync()) {
        targetDir = androidDownloads;
      }
    }

    targetDir ??= Directory.current;

    final filePath = '${targetDir.path}${Platform.pathSeparator}$filename';
    final file = File(filePath);
    await file.writeAsString(content, flush: true);

    return DownloadResult(
      success: true,
      filePath: file.path,
      message: 'Saved to ${file.path}',
    );
  } catch (e) {
    debugPrint('[Downloader] Failed to save file: $e');
    return DownloadResult(
      success: false,
      message: 'Failed to save file: $e',
    );
  }
}

/// Reveals or opens the downloaded file in the native system file manager (e.g. Windows Explorer).
Future<void> openDownloadedFile(String filePath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    }
  } catch (e) {
    debugPrint('[Downloader] Could not open file location: $e');
  }
}
