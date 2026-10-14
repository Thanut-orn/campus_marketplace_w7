import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:campus_marketplace_w7/database/app_database.dart';
import 'package:campus_marketplace_w7/models/cart_model.dart';
import 'package:campus_marketplace_w7/models/item.dart';
import 'package:campus_marketplace_w7/repositories/item_repository.dart';
import 'package:campus_marketplace_w7/repositories/favorites_repository.dart';
import 'package:campus_marketplace_w7/screens/home_page.dart';

class _FakeItemRepository implements ItemRepository {
  @override
  Future<List<Item>> getItems() {
    return Completer<List<Item>>().future;
  }
}

class _FakeFavoritesRepository implements FavoritesRepository {
  @override
  Future<void> addFavorite(int itemId, String title, double price, String imageUrl) async {}

  @override
  Future<List<FavoriteItem>> getAllFavorites() async => [];

  @override
  Future<void> removeFavorite(int itemId) async {}
}

void main() {
  testWidgets('แอปเปิดขึ้นมาแสดงชื่อแอปและสถานะกำลังโหลดสินค้า', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => CartModel(),
        child: MaterialApp(
          title: 'Campus Marketplace',
          home: HomePage(
            repositories: [_FakeItemRepository()],
            favoritesRepository: _FakeFavoritesRepository(),
          ),
        ),
      ),
    );

    expect(find.text('Campus Marketplace'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}