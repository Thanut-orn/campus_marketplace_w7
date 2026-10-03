import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _model = 'gemini-3.5-flash';

  static const List<String> _models = [
    _model,
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
    'gemini-2.5-flash',
  ];

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'ไม่พบ GEMINI_API_KEY กรุณารันแอปโดยระบุ --dart-define=GEMINI_API_KEY=your_key',
      );
    }

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
    });

    String? lastError;

    for (final model in _models.toSet()) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
      );

      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: requestBody,
              )
              .timeout(const Duration(seconds: 40));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates == null || candidates.isEmpty) {
              throw Exception('Gemini ไม่สามารถสร้างคำตอบได้ในครั้งนี้');
            }
            final parts = candidates.first['content']['parts'] as List<dynamic>;
            return parts.first['text'] as String;
          } else if (response.statusCode == 503) {
            lastError = 'เซิร์ฟเวอร์ Gemini กำลังโอเวอร์โหลดชั่วคราว (รหัส 503)';
            await Future.delayed(const Duration(milliseconds: 1500));
            continue;
          } else if (response.statusCode == 429) {
            lastError = 'ใช้งานเกินโควตาที่กำหนดในขณะนี้ กรุณาลองใหม่ภายหลัง (รหัส 429)';
            await Future.delayed(const Duration(milliseconds: 1500));
            break;
          } else {
            lastError = 'เซิร์ฟเวอร์ Gemini ตอบกลับผิดพลาด (รหัส ${response.statusCode})';
            break;
          }
        } on TimeoutException {
          lastError = 'การเชื่อมต่อกับ Gemini หมดเวลา';
          break;
        } catch (e) {
          lastError = e.toString().replaceFirst('Exception: ', '');
          break;
        }
      }
    }

    throw Exception(lastError ?? 'ไม่สามารถเรียกใช้ Gemini ได้ในขณะนี้');
  }
}
// ผลลัพธ์: สวัสดีค่ะ ยินดีต้อนรับสู่ร้านของเรานะคะ 😊 มีอะไรให้ช่วยดูสินค้าไหมคะ?
// หมายเหตุ: รันซ้ำด้วย Prompt เดิม ข้อความที่ได้อาจไม่เหมือนเดิมทุกตัวอักษร (ดูตอนที่ 1)