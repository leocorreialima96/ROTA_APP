import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../parsing/receipt_text_parser.dart';

/// Leitura da nota no próprio celular (Google ML Kit): funciona sem internet.
/// Na versão web não há ML Kit; a despesa é preenchida à mão.
class OcrService {
  final _parser = ReceiptTextParser();

  bool get available => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<ParsedReceipt?> readFile(String path) async {
    if (!available) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return _parser.parse(result.text);
    } catch (e) {
      debugPrint('Rota: falha na leitura da nota: $e');
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
