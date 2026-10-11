import 'dart:io';
import 'package:flutter/foundation.dart';

/// Reads `.env` from local filesystem on desktop/server/mobile.
Future<String?> readEnvFileFromDisk(String? customPath) async {
  if (kIsWeb) return null;
  try {
    final fileCandidates = [
      if (customPath != null) File(customPath),
      File('.env'),
      File('../.env'),
      File('../../.env'),
    ];
    for (final f in fileCandidates) {
      if (await f.exists()) {
        final content = await f.readAsString();
        if (content.isNotEmpty) return content;
      }
    }
  } catch (_) {}
  return null;
}
