import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/app_database.dart';
import '../models/item.dart';
import '../repositories/listing_draft_repository.dart';
import '../repositories/item_repository_firestore.dart';

class MyDraftsPage extends StatefulWidget {
  final ListingDraftRepository repository;

  const MyDraftsPage({super.key, required this.repository});

  @override
  State<MyDraftsPage> createState() => _MyDraftsPageState();
}

class _MyDraftsPageState extends State<MyDraftsPage> {
  late Future<List<ListingDraftRow>> _draftsFuture;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  void _loadDrafts() {
    setState(() {
      _draftsFuture = widget.repository.getAllDrafts();
    });
  }

  Future<void> _publishDraft(ListingDraftRow draft) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนทำการโพสต์ขาย')),
      );
      return;
    }

    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // 1. แสดง Dialog ถามราคาสินค้าก่อนเสมอ (เพราะร่างไม่มีราคาติดมา)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ตั้งราคาขายสินค้า'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'กำหนดราคาสำหรับ: ${draft.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ราคา (บาท)',
                    hintText: 'ระบุราคา เช่น 150',
                    border: OutlineInputBorder(),
                    prefixText: '฿ ',
                  ),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณากรอกราคา';
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null) {
                      return 'กรุณากรอกเป็นตัวเลขที่ถูกต้อง';
                    }
                    if (price <= 0) {
                      return 'ราคาต้องมากกว่า 0 บาท';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('ยืนยันโพสต์'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final price = double.parse(priceController.text.trim());

    // 2. แสดง Progress Indicator ระหว่างอัปโหลด
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังอัปโหลดรูปและโพสต์ขายสินค้า...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // ตรวจสอบการเชื่อมต่อเครือข่ายก่อนโพสต์ (สำหรับกรณีทดสอบ Offline ตามเงื่อนไขส่วนที่ 8)
      try {
        final lookup = await InternetAddress.lookup('example.com')
            .timeout(const Duration(seconds: 3));
        if (lookup.isEmpty || lookup[0].rawAddress.isEmpty) {
          throw const SocketException('No Internet Connection');
        }
      } catch (_) {
        throw Exception('ไม่สามารถเชื่อมต่อเครือข่ายได้ กรุณาตรวจสอบสัญญาณอินเทอร์เน็ต');
      }

      final imageFile = File(draft.imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('ไม่พบไฟล์รูปภาพในเครื่องที่ตำแหน่ง: ${draft.imagePath}');
      }

      // 3. แปลงรูปภาพเป็น Base64 Data URI เพื่อเก็บลง Firestore โดยตรง (แบบเดียวกับเพื่อน ไม่ต้องใช้ Storage / ไม่ต้องผูกบัตร)
      String downloadUrl;
      try {
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);
        downloadUrl = 'data:image/jpeg;base64,$base64String';
      } catch (_) {
        final seed = DateTime.now().millisecondsSinceEpoch % 1000;
        downloadUrl = 'https://picsum.photos/seed/$seed/500/500';
      }

      // 4. สร้าง Item จากข้อมูลร่าง + ราคาที่กรอก + sellerId
      final item = Item(
        id: 0,
        title: draft.title,
        price: price,
        description: draft.description,
        category: draft.category,
        imageUrl: downloadUrl,
        sellerId: user.uid,
      );

      // 5. เขียนเอกสารลง Firestore
      final firestoreRepo = ItemRepositoryFirestore();
      await firestoreRepo.postItem(item);

      // 6. หลังโพสต์สำเร็จ ลบร่างออกจาก Local Database
      await widget.repository.deleteDraft(draft.id);

      // ปิด Progress Dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Refresh รายการร่างบนหน้าจอ
      _loadDrafts();

      // แสดง SnackBar ยืนยัน
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('โพสต์ "${draft.title}" ขายจริงสำเร็จแล้ว!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // ปิด Progress Dialog หากเปิดอยู่
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโพสต์: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ร่างประกาศของฉัน'),
      ),
      body: FutureBuilder<List<ListingDraftRow>>(
        future: _draftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final drafts = snapshot.data ?? [];
          if (drafts.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีร่างประกาศที่บันทึกไว้'),
            );
          }
          return ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final imageFile = File(draft.imagePath);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: imageFile.existsSync()
                          ? Image.file(
                              imageFile,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                    ),
                    title: Text(
                      draft.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${draft.category}\n${draft.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ปุ่มโพสต์ขายจริง
                        ElevatedButton.icon(
                          onPressed: () => _publishDraft(draft),
                          icon: const Icon(Icons.cloud_upload, size: 16),
                          label: const Text('โพสต์ขายจริง'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // ปุ่มลบร่างประกาศ
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red.shade400,
                          tooltip: 'ลบร่าง',
                          onPressed: () async {
                            await widget.repository.deleteDraft(draft.id);
                            _loadDrafts();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'ลบร่าง "${draft.title}" เรียบร้อยแล้ว'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
