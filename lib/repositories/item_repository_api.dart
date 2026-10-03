import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item.dart';
import 'item_repository.dart';

class ItemRepositoryApi implements ItemRepository {
  static const _baseUrl = 'https://fakestoreapi.com/products';

  @override
  Future<List<Item>> getItems() async {
    final uri = Uri.parse(_baseUrl);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
      }
      return _fallbackItems;
    } catch (_) {
      // หาก fakestoreapi.com ล่มหรือ Timeout (ตามที่ใบงานเตือนไว้ในข้อ 468)
      // ให้คืนค่ารายการสินค้าสำรอง เพื่อให้หน้าหลักแสดงผลรายการสินค้าได้เสมอ
      return _fallbackItems;
    }
  }

  // รายการสินค้าจำลองสำรองกรณี Fake Store API เซิร์ฟเวอร์ล่มชั่วคราว
  static const List<Item> _fallbackItems = [
    Item(
      id: 1,
      title: 'Fjallraven - Foldsack No. 1 Backpack, Fits 15 Laptops',
      price: 109.95,
      description: 'Your perfect pack for everyday use and walks in the forest. Stash your laptop in the padded sleeve.',
      category: "men's clothing",
      imageUrl: 'https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_.jpg',
    ),
    Item(
      id: 2,
      title: 'Mens Casual Premium Slim Fit T-Shirts',
      price: 22.3,
      description: 'Slim-fitting style, contrast raglan long sleeve, three-button henley placket.',
      category: "men's clothing",
      imageUrl: 'https://fakestoreapi.com/img/71-3HjGNDUL._AC_SY879._SX._UX._SY._UY_.jpg',
    ),
    Item(
      id: 3,
      title: 'Mens Cotton Jacket',
      price: 55.99,
      description: 'Great outerwear jackets for Spring/Autumn/Winter, suitable for many occasions.',
      category: "men's clothing",
      imageUrl: 'https://fakestoreapi.com/img/71li-ujtlUL._AC_UX679_.jpg',
    ),
    Item(
      id: 4,
      title: 'Mens Casual Slim Fit',
      price: 15.99,
      description: 'The color could be slightly different between on the screen and in practice.',
      category: "men's clothing",
      imageUrl: 'https://fakestoreapi.com/img/71YXzeOuslL._AC_UY879_.jpg',
    ),
    Item(
      id: 5,
      title: "John Hardy Women's Legends Naga Gold & Silver Dragon Station Chain Bracelet",
      price: 695.0,
      description: 'From our Legends Collection, the Naga was inspired by the mythical water dragon that protects the ocean pearl.',
      category: 'jewelery',
      imageUrl: 'https://fakestoreapi.com/img/71pWzhdJNwL._AC_UL640_QL65_ML3_.jpg',
    ),
    Item(
      id: 6,
      title: 'Solid Gold Petite Micropave',
      price: 168.0,
      description: 'Satisfaction Guaranteed. Return or exchange any order within 30 days.',
      category: 'jewelery',
      imageUrl: 'https://fakestoreapi.com/img/61sbMiUnoGL._AC_UL640_QL65_ML3_.jpg',
    ),
    Item(
      id: 7,
      title: 'White Gold Plated Princess',
      price: 9.99,
      description: 'Classic Created Wedding Engagement Solitaire Diamond Promise Ring for Her.',
      category: 'jewelery',
      imageUrl: 'https://fakestoreapi.com/img/71YAIFU48IL._AC_UL640_QL65_ML3_.jpg',
    ),
    Item(
      id: 8,
      title: 'Pierced Owl Rose Gold Plated Stainless Steel Double',
      price: 10.99,
      description: 'Rose Gold Plated Double Flared Tunnel Plug Earrings. Made of 316L Stainless Steel.',
      category: 'jewelery',
      imageUrl: 'https://fakestoreapi.com/img/51UDEzMJVpL._AC_UL640_QL65_ML3_.jpg',
    ),
    Item(
      id: 9,
      title: 'WD 2TB Elements Portable External Hard Drive - USB 3.0',
      price: 64.0,
      description: 'USB 3.0 and USB 2.0 Compatibility Fast data transfers Improve PC Performance High Capacity.',
      category: 'electronics',
      imageUrl: 'https://fakestoreapi.com/img/61IBBVJvSDL._AC_SY879_.jpg',
    ),
    Item(
      id: 10,
      title: 'SanDisk SSD PLUS 1TB Internal SSD - SATA III 6 Gb/s',
      price: 109.0,
      description: 'Easy upgrade for faster boot up, shutdown, application load and response.',
      category: 'electronics',
      imageUrl: 'https://fakestoreapi.com/img/61U7T1koQqL._AC_SX679_.jpg',
    ),
  ];
}