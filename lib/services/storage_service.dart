import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// อัปโหลดรูปภาพสินค้าขึ้น Firebase Storage และคืนค่าเป็น Download URL
  Future<String> uploadListingImage(File imageFile, String sellerId) async {
    // 1. ตั้งชื่อไฟล์บน Storage ให้ไม่ซ้ำกัน โดยใช้ sellerId ผสมกับ millisecondsSinceEpoch
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileExtension = imageFile.path.contains('.')
        ? imageFile.path.split('.').last
        : 'jpg';
    final fileName = '${sellerId}_$timestamp.$fileExtension';

    // 2. กำหนด Reference ไปยังโฟลเดอร์ listings บน Firebase Storage
    final ref = _storage.ref().child('listings').child(fileName);

    // 3. เริ่มอัปโหลดไฟล์ด้วย putFile() และรอให้เสร็จสมบูรณ์
    final uploadTask = ref.putFile(imageFile);
    await uploadTask;

    // 4. เรียก getDownloadURL() หลังจากอัปโหลดเสร็จสมบูรณ์แล้ว
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }
}
