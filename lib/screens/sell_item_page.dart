import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/listing_draft.dart';
import '../services/gemini_vision_service.dart';
import '../repositories/listing_draft_repository.dart';
import 'my_drafts_page.dart';

class SellItemPage extends StatefulWidget {
  final ListingDraftRepository draftRepository;

  const SellItemPage({super.key, required this.draftRepository});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  // ค่าคงที่ Prompt สำหรับให้ Gemini Vision วิเคราะห์รูปภาพสินค้าจริง
  static const _prompt = '''
คุณคือผู้ช่วยเขียนประกาศขายของมือสองในตลาดนัดออนไลน์สำหรับนักศึกษามหาวิทยาลัย
จากรูปภาพสินค้าที่แนบมา ให้วิเคราะห์แล้วตอบกลับเป็น JSON เท่านั้น ตามโครงสร้างนี้:
{
  "title": "ชื่อประกาศสั้นกระชับ ไม่เกิน 40 ตัวอักษร",
  "category": "หมวดหมู่ที่เหมาะสมที่สุด เลือกจาก: หนังสือเรียน, อุปกรณ์อิเล็กทรอนิกส์, ของแต่งหอพัก, เสื้อผ้า, อื่นๆ",
  "description": "คำบรรยายสินค้า 2-3 ประโยค ที่ดึงดูดผู้ซื้อและบอกสภาพของสินค้าตามที่เห็นในภาพ"
}
ห้ามตอบข้อความอื่นนอกเหนือจาก JSON ดังกล่าว
''';

  // ตัวแปรเก็บรูปภาพที่เลือกไว้
  File? _selectedImage;

  // ตัวแปรสำหรับจัดการ 3 สถานะ: กำลังวิเคราะห์ / สำเร็จ / ผิดพลาด
  bool _isLoading = false;
  String? _errorMessage = null;
  ListingDraft? _draft;
  // ร่างประกาศฉบับสุดท้ายที่กดยืนยันแล้ว (ขั้นตอนที่ 5.2)
  ListingDraft? _confirmedDraft;

  // Controllers สำหรับฟอร์มตรวจทานและแก้ไข (Step 5.1 Human-in-the-loop)
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ฟังก์ชันเลือกรูปภาพจาก Gallery
  Future<void> pickImage() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return;

    setState(() {
      _selectedImage = File(result.path);
      // เมื่อเลือกรูปใหม่ ให้เคลียร์ผลวิเคราะห์และ error เดิม
      _errorMessage = null;
      _draft = null;
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
    });
  }

  // ฟังก์ชันเรียก GeminiVisionService วิเคราะห์รูปภาพ (ขั้นตอนที่ 4.3)
  Future<void> analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _draft = null;
    });

    try {
      final draft = await GeminiVisionService().analyzeProductImage(
        _selectedImage!,
        _prompt,
      );

      setState(() {
        _draft = draft;
        _titleController.text = draft.title;
        _categoryController.text = draft.category;
        _descriptionController.text = draft.description;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงขายสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ร่างประกาศของฉัน',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyDraftsPage(repository: widget.draftRepository),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // แสดงรูปภาพที่เลือก หรือ Placeholder
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
              ),

            const SizedBox(height: 16),

            // ปุ่ม "เลือกรูปภาพสินค้า"
            ElevatedButton.icon(
              onPressed: _isLoading ? null : pickImage,
              icon: const Icon(Icons.image_search),
              label: const Text('เลือกรูปภาพสินค้า'),
            ),

            const SizedBox(height: 12),

            // ปุ่ม "ให้ AI ช่วยแนะนำ"
            ElevatedButton.icon(
              onPressed: (_selectedImage == null || _isLoading) ? null : analyzeImage,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ให้ AI ช่วยแนะนำ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[100],
                foregroundColor: Colors.purple[900],
              ),
            ),

            // สถานะที่ 1: กำลังวิเคราะห์
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'AI กำลังวิเคราะห์ภาพสินค้า...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],

            // สถานะที่ 2: ผิดพลาด
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // สถานะที่ 3: สำเร็จ พร้อมฟอร์มให้ตรวจทานและแก้ไข (Step 5.1 & 5.2)
            if (_draft != null) ...[
              const SizedBox(height: 24),
              const Text(
                'ข้อมูลที่ AI แนะนำ (สามารถแก้ไขได้):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อประกาศ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'หมวดหมู่',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'คำบรรยายสินค้า',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  FocusScope.of(context).unfocus();

                  final confirmed = ListingDraft(
                    title: _titleController.text.trim(),
                    category: _categoryController.text.trim(),
                    description: _descriptionController.text.trim(),
                  );

                  if (_selectedImage != null) {
                    try {
                      await widget.draftRepository.saveDraft(
                        confirmed,
                        _selectedImage!.path,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
                        );
                      }
                      return;
                    }
                  }

                  setState(() {
                    _confirmedDraft = confirmed;
                    _selectedImage = null;
                    _draft = null;
                    _titleController.clear();
                    _categoryController.clear();
                    _descriptionController.clear();
                    _errorMessage = null;
                  });

                  debugPrint('บันทึกร่างประกาศ: ${_confirmedDraft?.title}');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('บันทึกร่างประกาศเรียบร้อยแล้ว'),
                        duration: Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('ยืนยันร่างประกาศ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}