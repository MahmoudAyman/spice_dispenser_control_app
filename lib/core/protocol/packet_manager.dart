import 'dart:convert';

class PacketManager {
  static const int mtuSize = 180;
  static final Map<String, List<int>> _buffers = {};

  /// SPLIT LARGE JSON
  static List<List<int>> splitPacket(
    String jsonString,
  ) {
    final bytes = utf8.encode(
      jsonString,
    );
    List<List<int>> packets = [];
    for (int i = 0; i < bytes.length; i += mtuSize) {
      final end = (i + mtuSize < bytes.length) ? i + mtuSize : bytes.length;
      packets.add(
        bytes.sublist(i, end),
      );
    }
    return packets;
  }

  /// MERGE RECEIVED PACKETS AND EXTRACT COMPLETE JSON MESSAGES
  static List<String> mergePackets(List<int> data, String characteristicId) {
    if (!_buffers.containsKey(characteristicId)) {
      _buffers[characteristicId] = [];
    }
    _buffers[characteristicId]!.addAll(data);

    final messages = <String>[];

    try {
      String bufferStr = utf8.decode(_buffers[characteristicId]!, allowMalformed: true);
      
      while (true) {
        final startIndex = bufferStr.indexOf('{');
        if (startIndex == -1) {
          // No start of JSON, clear buffer and break
          _buffers[characteristicId] = [];
          break;
        }

        // Find matching closing brace
        int braceCount = 0;
        int endIndex = -1;
        bool inString = false;
        bool escaped = false;

        for (int i = startIndex; i < bufferStr.length; i++) {
          final char = bufferStr[i];

          if (escaped) {
            escaped = false;
            continue;
          }

          if (char == '\\') {
            escaped = true;
            continue;
          }

          if (char == '"') {
            inString = !inString;
            continue;
          }

          if (!inString) {
            if (char == '{') {
              braceCount++;
            } else if (char == '}') {
              braceCount--;
              if (braceCount == 0) {
                endIndex = i;
                break;
              }
            }
          }
        }

        if (endIndex != -1) {
          // Found a complete JSON object
          final jsonMsg = bufferStr.substring(startIndex, endIndex + 1);

          try {
            // Validate JSON
            jsonDecode(jsonMsg);
            messages.add(jsonMsg);
          } catch (e) {
            print('PacketManager JSON parse error: $e for payload: $jsonMsg');
          }

          // Remove the processed part from the bufferStr
          bufferStr = bufferStr.substring(endIndex + 1);
        } else {
          // No complete JSON object found yet, keep the rest of the buffer
          break;
        }
      }

      // Update the byte buffer with what's left
      _buffers[characteristicId] = utf8.encode(bufferStr).toList();

    } catch (e) {
      print('PacketManager error in mergePackets: $e');
      // Do NOT clear the buffer, let it try to recover on the next packet
    }

    return messages;
  }

  static void clearBuffer(String characteristicId) {
    if (_buffers.containsKey(characteristicId)) {
      _buffers.remove(characteristicId);
    }
  }
}