import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/cart_model.dart';
import '../repositories/item_repository.dart';
import '../repositories/favorites_repository.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import 'checkout_page.dart';

class HomePage extends StatefulWidget {
  final List<ItemRepository> repositories;
  final FavoritesRepository favoritesRepository;

  const HomePage({
    super.key,
    required this.repositories,
    required this.favoritesRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Item>> _itemsFuture;
  bool _isGeminiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    _itemsFuture = _fetchAllItems();
  }

  Future<List<Item>> _fetchAllItems() async {
    final results = await Future.wait(
      widget.repositories.map((repo) => repo.getItems()),
    );
    return results.expand((items) => items).toList();
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String = imageUrl.split(',').last;
        return Image.memory(
          base64Decode(base64String),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 52),
        );
      } catch (_) {
        return const Icon(Icons.broken_image, size: 52);
      }
    }
    return Image.network(
      imageUrl,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, size: 52),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartModel>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่พบสินค้า'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _loadItems();
              });
            },
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isStudentPost =
                    item.sellerId != null && item.sellerId!.isNotEmpty;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildProductImage(item.imageUrl),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge แสดงแหล่งที่มาของสินค้า (API หรือ นศ. โพสต์)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isStudentPost
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isStudentPost
                                ? Colors.purple.shade300
                                : Colors.blue.shade300,
                            ),
                          ),
                          child: Text(
                            isStudentPost ? '🎓 นักศึกษา' : '🏪 API',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isStudentPost
                                  ? Colors.purple.shade800
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${item.price} บาท',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () async {
                            try {
                              await widget.favoritesRepository.addFavorite(
                                item.id,
                                item.title,
                                item.price,
                                item.imageUrl,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'บันทึก "${item.title}" ลงในรายการโปรดแล้ว'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('เกิดข้อผิดพลาด: $e')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: () {
                            context.read<CartModel>().add(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'เพิ่ม "${item.title}" ลงตะกร้าแล้ว')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isGeminiLoading
            ? null
            : () async {
                setState(() => _isGeminiLoading = true);

                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กำลังส่งคำถามไปหา Gemini...')),
                );

                try {
                  final response = await GeminiService().generateText(
                    'ช่วยแต่งประโยคทักทายลูกค้าร้านค้าออนไลน์แบบเป็นกันเอง',
                  );

                  debugPrint('========== คำตอบจาก Gemini ==========');
                  debugPrint(response);
                  debugPrint('=====================================');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isGeminiLoading = false);
                  }
                }
              },
        tooltip: 'ทดสอบ Gemini',
        child: _isGeminiLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.smart_toy),
      ),
    );
  }
}