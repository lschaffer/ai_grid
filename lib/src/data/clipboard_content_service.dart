import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The recognized category of content extracted from the system clipboard.
enum ClipboardContentType {
  image,
  document,
  text,
}

/// A structured representation of data extracted from the clipboard.
class ClipboardPayload {
  final ClipboardContentType type;
  final String name;
  final String mimeType;
  final Uint8List? bytes;
  final String? text;
  final String? filePath;

  const ClipboardPayload({
    required this.type,
    required this.name,
    required this.mimeType,
    this.bytes,
    this.text,
    this.filePath,
  });

  /// True if this payload represents media (image or document) rather than plain text.
  bool get isMedia =>
      type == ClipboardContentType.image || type == ClipboardContentType.document;
}

/// Unified service for extracting images, documents, and rich content from
/// the system clipboard across desktop (Windows/macOS/Linux), mobile, and web.
class ClipboardContentService {
  /// Reads the current system clipboard and identifies if it holds:
  /// 1. A native bitmap image (Windows clipboard CF_BITMAP/PNG)
  /// 2. Native file drop list (files copied in Explorer)
  /// 3. A file path pointing to an existing file (image or document)
  /// 4. A base64 data URI (data:image/...;base64,...)
  /// 5. Normal text
  static Future<List<ClipboardPayload>> readClipboard() async {
    // 1. On Windows desktop, check for native clipboard image or file drop list
    if (!kIsWeb && Platform.isWindows) {
      try {
        final nativePayloads = await _readWindowsNativeClipboard();
        if (nativePayloads.isNotEmpty) {
          return nativePayloads;
        }
      } catch (e) {
        debugPrint('[ClipboardContentService] Windows native check failed: $e');
      }
    }

    // 2. Check standard text clipboard for Base64 Data URIs, file paths, or text
    try {
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      if (textData?.text != null && textData!.text!.trim().isNotEmpty) {
        final raw = textData.text!.trim();

        // 2a. Base64 Data URI (e.g. data:image/png;base64,iVBOR...)
        if (raw.startsWith('data:image/')) {
          final uriPayload = await _parseDataUri(raw);
          if (uriPayload != null) return [uriPayload];
        }

        // 2b. Check if raw text represents existing file paths on disk
        if (!kIsWeb) {
          final filePayloads = await _parsePotentialFilePaths(raw);
          if (filePayloads.isNotEmpty) return filePayloads;
        }

        // 2c. Normal text fallback
        return [
          ClipboardPayload(
            type: ClipboardContentType.text,
            name: 'text',
            mimeType: 'text/plain',
            text: raw,
          ),
        ];
      }
    } catch (e) {
      debugPrint('[ClipboardContentService] Text clipboard check failed: $e');
    }

    return const [];
  }

  /// Inspects Windows native clipboard formats (Bitmap and FileDropList) via PowerShell.
  static Future<List<ClipboardPayload>> _readWindowsNativeClipboard() async {
    const script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
    \$img = [System.Windows.Forms.Clipboard]::GetImage()
    \$ms = New-Object System.IO.MemoryStream
    \$img.Save(\$ms, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output ("IMG:" + [Convert]::ToBase64String(\$ms.ToArray()))
} elseif ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
    \$files = [System.Windows.Forms.Clipboard]::GetFileDropList()
    Write-Output ("FILES:" + [string]::Join("|", \$files))
} else {
    Write-Output "NONE"
}
''';

    final utf16leBytes = <int>[];
    for (final b in script.codeUnits) {
      utf16leBytes.add(b & 0xFF);
      utf16leBytes.add((b >> 8) & 0xFF);
    }
    final encodedCmd = base64.encode(utf16leBytes);

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-EncodedCommand', encodedCmd],
    );

    if (result.exitCode != 0) return const [];

    final output = result.stdout.toString().trim();

    // Native Image
    if (output.startsWith('IMG:')) {
      final b64 = output.substring(4).trim();
      if (b64.isNotEmpty) {
        final rawBytes = base64.decode(b64);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        return [
          ClipboardPayload(
            type: ClipboardContentType.image,
            name: 'clipboard_screenshot_$timestamp.png',
            mimeType: 'image/png',
            bytes: rawBytes,
          ),
        ];
      }
    }

    // Native File Drop List
    if (output.startsWith('FILES:')) {
      final rawPaths = output.substring(6).trim();
      final paths = rawPaths.split('|').where((p) => p.trim().isNotEmpty);
      final payloads = <ClipboardPayload>[];

      for (final p in paths) {
        final file = File(p.trim());
        if (await file.exists()) {
          final name = p.trim().split(RegExp(r'[/\\]')).last;
          final mime = _mimeFromExtension(name);
          final bytes = await file.readAsBytes();

          if (_isImageMime(mime)) {
            payloads.add(
              ClipboardPayload(
                type: ClipboardContentType.image,
                name: name,
                mimeType: mime,
                bytes: bytes,
                filePath: file.path,
              ),
            );
          } else {
            String? textContent;
            if (_isTextFile(mime, name)) {
              try {
                textContent = await file.readAsString();
              } catch (_) {}
            }
            payloads.add(
              ClipboardPayload(
                type: ClipboardContentType.document,
                name: name,
                mimeType: mime,
                bytes: bytes,
                text: textContent,
                filePath: file.path,
              ),
            );
          }
        }
      }

      if (payloads.isNotEmpty) return payloads;
    }

    return const [];
  }

  static Future<ClipboardPayload?> _parseDataUri(String uri) async {
    try {
      final commaIdx = uri.indexOf(',');
      if (commaIdx == -1) return null;

      final header = uri.substring(0, commaIdx);
      final dataStr = uri.substring(commaIdx + 1);

      var mime = 'image/png';
      final mimeMatch = RegExp(r'data:([^;]+);').firstMatch(header);
      if (mimeMatch != null) {
        mime = mimeMatch.group(1) ?? 'image/png';
      }

      final rawBytes = base64.decode(dataStr);

      return ClipboardPayload(
        type: ClipboardContentType.image,
        name: 'clipboard_image_${DateTime.now().millisecondsSinceEpoch}.png',
        mimeType: mime,
        bytes: rawBytes,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<ClipboardPayload>> _parsePotentialFilePaths(String input) async {
    final lines = input
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'^["' "'" r']|["' "'" r']$'), ''))
        .where((l) => l.isNotEmpty);

    final payloads = <ClipboardPayload>[];

    for (var path in lines) {
      if (path.startsWith('file:///')) {
        path = Uri.parse(path).toFilePath();
      } else if (path.startsWith('file://')) {
        path = Uri.parse(path).toFilePath();
      }

      final file = File(path);
      if (await file.exists()) {
        final name = path.split(RegExp(r'[/\\]')).last;
        final mime = _mimeFromExtension(name);
        final bytes = await file.readAsBytes();

        if (_isImageMime(mime)) {
          payloads.add(
            ClipboardPayload(
              type: ClipboardContentType.image,
              name: name,
              mimeType: mime,
              bytes: bytes,
              filePath: file.path,
            ),
          );
        } else {
          String? textContent;
          if (_isTextFile(mime, name)) {
            try {
              textContent = await file.readAsString();
            } catch (_) {}
          }
          payloads.add(
            ClipboardPayload(
              type: ClipboardContentType.document,
              name: name,
              mimeType: mime,
              bytes: bytes,
              text: textContent,
              filePath: file.path,
            ),
          );
        }
      }
    }

    return payloads;
  }

  static String _mimeFromExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = <String, String>{
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'tsv': 'text/tab-separated-values',
      'json': 'application/json',
      'xml': 'application/xml',
      'yaml': 'text/yaml',
      'yml': 'text/yaml',
      'html': 'text/html',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  static bool _isImageMime(String mime) => mime.toLowerCase().startsWith('image/');

  static bool _isTextFile(String mimeType, String filename) {
    final mime = mimeType.toLowerCase();
    if (mime.startsWith('text/')) return true;
    final name = filename.toLowerCase();
    return name.endsWith('.txt') ||
        name.endsWith('.md') ||
        name.endsWith('.csv') ||
        name.endsWith('.tsv') ||
        name.endsWith('.json') ||
        name.endsWith('.yaml') ||
        name.endsWith('.yml') ||
        name.endsWith('.html');
  }
}
