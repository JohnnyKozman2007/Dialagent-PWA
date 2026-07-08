import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:base32/base32.dart';

class TOTPUtil {
  static String generateSecret() {
    final random = Random.secure();
    Uint8List bytes = Uint8List(20);
    for (int i = 0; i < 20; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base32.encode(bytes);
  }

  static String getQRCodeUrl({required String appName, required String secretKey, required String issuer}) {
    return 'otpauth://totp/$issuer:$appName?secret=$secretKey&issuer=$issuer';
  }

  static bool verifyCode({required String secretKey, required String totpCode}) {
    try {
      Uint8List keyBytes = base32.decode(secretKey);
      int counter = (DateTime.now().millisecondsSinceEpoch / 1000 / 30).floor();

      String code = _generateTOTP(keyBytes, counter);
      if (code == totpCode) return true;

      String previousCode = _generateTOTP(keyBytes, counter - 1);
      if (previousCode == totpCode) return true;

      String nextCode = _generateTOTP(keyBytes, counter + 1);
      if (nextCode == totpCode) return true;

      return false;
    } catch (e) {
      print('TOTP Error: $e');
      return false;
    }
  }

  static String _generateTOTP(Uint8List keyBytes, int counter) {
    List<int> counterBytes = List.filled(8, 0);
    for (int i = 7; i >= 0; i--) {
      counterBytes[7 - i] = (counter >> (8 * i)) & 0xFF;
    }

    Hmac hmac = Hmac(sha1, keyBytes);
    List<int> hash = hmac.convert(counterBytes).bytes;

    int offset = hash[hash.length - 1] & 0xF;
    int binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    int otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }
}