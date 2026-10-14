import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import 'item_repository.dart';

class ItemRepositoryFirestore implements ItemRepository {
  final FirebaseFirestore _firestore;

  ItemRepositoryFirestore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('items');

  @override
  Future<List<Item>> getItems() async {
    final snapshot = await _itemsCollection.get();
    return snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();
  }

  Future<void> postItem(Item item) async {
    await _itemsCollection.add(item.toFirestore());
  }

  Stream<List<Item>> watchMyListings(String sellerId) {
    return _itemsCollection
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList());
  }
}
