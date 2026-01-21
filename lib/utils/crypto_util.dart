import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class CryptoUtil {
  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return _toHex(bytes);
  }

  static String hashWithSalt(String text, String salt) {
    final bytes = utf8.encode('$salt::$text');
    final digest = sha256.convert(bytes);
    return digest.toString(); // hex
  }

  static bool verify(String plain, String salt, String hexHash) {
    final h = hashWithSalt(plain, salt);
    return _constantTimeEquals(h, hexHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static String _toHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
