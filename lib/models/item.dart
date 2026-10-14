import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final int id;
  final String title;
  final double price;
  final String description;
  final String category;
  final String imageUrl;
  final String? sellerId;

  const Item({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.sellerId,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final title = json['title'] as String;
    final price = (json['price'] as num).toDouble();
    final description = json['description'] as String;
    final category = json['category'] as String;
    final imageUrl = json['image'] as String; // key 'image' ไม่ตรงกับชื่อ field imageUrl

    return Item(
      id: id,
      title: title,
      price: price,
      description: description,
      category: category,
      imageUrl: imageUrl,
      sellerId: json['sellerId'] as String?,
    );
  }

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Item(
      id: data['id'] is int
          ? data['id'] as int
          : (int.tryParse(doc.id) ?? doc.id.hashCode),
      title: data['title'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? data['image'] as String? ?? '',
      sellerId: data['sellerId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'price': price,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
    };
  }
}