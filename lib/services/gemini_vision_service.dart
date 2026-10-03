import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/listing_draft.dart';

class GeminiVisionService {
  static const _model = 'gemini-3.5-flash';
  static const List<String> _models = [
    _model,
    'gemini-2.0-flash',
    'gemini-1.5-flash-8b',
    'gemini-2.5-flash',
  ];
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<ListingDraft> analyzeProductImage(File imageFile, String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'ไม่พบ GEMINI_API_KEY กรุณารันแอปโดยระบุ --dart-define=GEMINI_API_KEY=your_key',
      );
    }

    // 1. อ่านไฟล์ภาพเป็นไบต์ แล้วเข้ารหัส Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // ระบุ mimeType ให้ตรงกับนามสกุลไฟล์
    final path = imageFile.path.toLowerCase();
    String mimeType = 'image/jpeg';
    if (path.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (path.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (path.endsWith('.heic')) {
      mimeType = 'image/heic';
    }

    // 2. ส่งภาพพร้อม Prompt ใน parts เดียวกัน และใช้ responseSchema บังคับให้ตอบเป็น JSON
    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image,
              }
            },
            {
              'text': prompt,
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'category': {'type': 'STRING'},
            'description': {'type': 'STRING'},
          },
          'required': ['title', 'category', 'description'],
        },
      },
    });

    String? lastError;

    // วนลูปโมเดลหลักและโมเดลสำรอง เพื่อป้องกันปัญหา 503 หรือ 429
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
              .timeout(const Duration(seconds: 60));

          if (response.statusCode == 200) {
            // jsonDecode ชั้นที่ 1: แปลง Response Body เป็น Map
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
            if (promptFeedback != null && promptFeedback['blockReason'] != null) {
              throw Exception(
                'เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น',
              );
            }

            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates == null || candidates.isEmpty) {
              throw Exception(
                'AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น',
              );
            }

            final firstCandidate = candidates.first as Map<String, dynamic>;
            final finishReason = firstCandidate['finishReason'] as String?;
            if (finishReason == 'SAFETY') {
              throw Exception(
                'เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น',
              );
            }

            final content = firstCandidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts == null || parts.isEmpty) {
              throw Exception('ไม่พบข้อมูลคำตอบจาก Gemini');
            }

            final rawText = parts.first['text'] as String;

            // jsonDecode ชั้นที่ 2: แปลงข้อความ JSON String จาก AI เป็น Map
            final jsonDraft = jsonDecode(rawText) as Map<String, dynamic>;
            return ListingDraft.fromJson(jsonDraft);
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
          lastError = 'การเชื่อมต่อกับ Gemini หมดเวลา (Timeout 60 วินาที)';
          break;
        } catch (e) {
          final msg = e.toString().replaceFirst('Exception: ', '');
          if (msg.contains('ไม่ปลอดภัย') || msg.contains('ไม่เหมาะสม')) {
            throw Exception(msg);
          }
          lastError = msg;
          break;
        }
      }
    }

    throw Exception(lastError ?? 'ไม่สามารถวิเคราะห์ภาพได้ในขณะนี้');
  }
}
