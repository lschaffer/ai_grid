import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart PDF text and table content extractor.
///
/// Parses PDF content streams, handles decompression filters (FlateDecode, ASCII85Decode),
/// and extracts text literals for tabular reasoning and LLM ingestion.
class PdfTableExtractor {
  /// Extracts all visible plain text strings from a PDF document byte array.
  static String extractText(Uint8List bytes) {
    if (bytes.length < 10) return '';

    final buffer = StringBuffer();
    final content = latin1.decode(bytes);
    const streamKeyword = 'stream';
    const endstreamKeyword = 'endstream';

    int pos = 0;

    while (true) {
      final streamPos = content.indexOf(streamKeyword, pos);
      if (streamPos == -1) break;

      // Ensure it's the keyword "stream" (not part of "endstream")
      if (streamPos >= 3 && content.substring(streamPos - 3, streamPos) == 'end') {
        pos = streamPos + 6;
        continue;
      }

      final endPos = content.indexOf(endstreamKeyword, streamPos);
      if (endPos == -1) break;

      // Look back for preceding dictionary << ... >>
      final dictStart = content.lastIndexOf('<<', streamPos);
      final dict = (dictStart != -1 && dictStart < streamPos)
          ? content.substring(dictStart, streamPos)
          : '';

      // Determine stream binary payload bounds
      var dataStart = streamPos + 6;
      if (content.startsWith('\r\n', dataStart)) {
        dataStart += 2;
      } else if (content.startsWith('\n', dataStart) || content.startsWith('\r', dataStart)) {
        dataStart += 1;
      }

      var dataEnd = endPos;
      if (dataEnd > dataStart && (content[dataEnd - 1] == '\n' || content[dataEnd - 1] == '\r')) {
        dataEnd--;
        if (dataEnd > dataStart && content[dataEnd - 1] == '\r') {
          dataEnd--;
        }
      }

      if (dataEnd > dataStart && dataEnd <= bytes.length) {
        Uint8List streamBytes = bytes.sublist(dataStart, dataEnd);

        try {
          if (dict.contains('ASCII85Decode')) {
            streamBytes = decodeAscii85(streamBytes);
          }
          if (dict.contains('FlateDecode')) {
            streamBytes = Uint8List.fromList(zlib.decode(streamBytes));
          }

          final decompressed = latin1.decode(streamBytes);
          final text = parseStreamText(decompressed);
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        } catch (_) {
          // If decompression fails on an image or font stream, continue to next stream
        }
      }

      pos = endPos + 9;
    }

    return buffer.toString().trim();
  }

  /// Decodes Adobe ASCII85 encoded byte stream into binary.
  static Uint8List decodeAscii85(Uint8List input) {
    final output = <int>[];
    var count = 0;
    var tuple = 0;

    for (var i = 0; i < input.length; i++) {
      final b = input[i];
      if (b == 0x7E) break; // '~' end marker
      if (b <= 0x20) continue; // skip whitespace
      if (b == 0x7A) {
        // 'z' special shortcut for 4 zero bytes
        if (count != 0) continue;
        output.addAll([0, 0, 0, 0]);
        continue;
      }

      if (b < 0x21 || b > 0x75) continue; // outside '!' to 'u'
      tuple = tuple * 85 + (b - 0x21);
      count++;

      if (count == 5) {
        output.add((tuple >> 24) & 0xFF);
        output.add((tuple >> 16) & 0xFF);
        output.add((tuple >> 8) & 0xFF);
        output.add(tuple & 0xFF);
        tuple = 0;
        count = 0;
      }
    }

    if (count > 1) {
      for (var i = count; i < 5; i++) {
        tuple = tuple * 85 + 84;
      }
      for (var i = 0; i < count - 1; i++) {
        output.add((tuple >> (24 - i * 8)) & 0xFF);
      }
    }

    return Uint8List.fromList(output);
  }

  /// Parses text operations from a decompressed PDF content stream.
  static String parseStreamText(String stream) {
    final sb = StringBuffer();

    // Match text blocks enclosed in BT ... ET
    final btEtRegex = RegExp(r'BT([\s\S]*?)ET');
    for (final block in btEtRegex.allMatches(stream)) {
      final btContent = block.group(1) ?? '';

      // 1. Tj operators: (text) Tj
      final tjRegex = RegExp(r'\(((?:[^\\)]|\\.)*)\)\s*Tj');
      for (final m in tjRegex.allMatches(btContent)) {
        final raw = _unescapePdfString(m.group(1) ?? '');
        if (raw.isNotEmpty) {
          sb.write('$raw ');
        }
      }

      // 2. TJ array operators: [(t1) 120 (t2)] TJ
      final tjArrayRegex = RegExp(r'\[([\s\S]*?)\]\s*TJ');
      for (final m in tjArrayRegex.allMatches(btContent)) {
        final arrayContent = m.group(1) ?? '';
        final innerStrings = RegExp(r'\(((?:[^\\)]|\\.)*)\)').allMatches(arrayContent);
        for (final inner in innerStrings) {
          final raw = _unescapePdfString(inner.group(1) ?? '');
          if (raw.isNotEmpty) {
            sb.write('$raw ');
          }
        }
      }

      sb.writeln();
    }

    return sb.toString().trim();
  }

  static String _unescapePdfString(String raw) {
    var s = raw
        .replaceAll(r'\)', ')')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');

    // Decode octal escapes e.g. \227 -> em-dash or character
    final octalRegex = RegExp(r'\\([0-7]{1,3})');
    s = s.replaceAllMapped(octalRegex, (m) {
      final octalVal = int.tryParse(m.group(1)!, radix: 8);
      if (octalVal != null) {
        return String.fromCharCode(octalVal);
      }
      return m.group(0)!;
    });

    return s;
  }
}
