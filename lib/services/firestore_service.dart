import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> add(
      String collection,
      String documentId,
      Map<String, dynamic> data,
      ) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data);
  }

  Future<Map<String, dynamic>?> get(
      String collection,
      String documentId,
      ) async {
    final document = await _firestore
        .collection(collection)
        .doc(documentId)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data() ?? {};
    final id = (data['id'] != null && data['id'].toString().isNotEmpty)
        ? data['id'].toString()
        : document.id;

    return {
      ...data,
      'id': id,
    };
  }

  Future<void> update(
      String collection,
      String documentId,
      Map<String, dynamic> data,
      ) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .update(data);
  }

  Future<void> delete(
      String collection,
      String documentId,
      ) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .delete();
  }

  Future<List<Map<String, dynamic>>> getAll(
      String collection,
      ) async {
    final snapshot =
    await _firestore.collection(collection).get();

    return snapshot.docs.map((document) {
      final data = document.data();
      final id = (data['id'] != null && data['id'].toString().isNotEmpty)
          ? data['id'].toString()
          : document.id;
      return {
        ...data,
        'id': id,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> whereEquals(
    String collection,
    String field,
    dynamic value,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();

    return snapshot.docs.map((document) {
      final data = document.data();
      final id = (data['id'] != null && data['id'].toString().isNotEmpty)
          ? data['id'].toString()
          : document.id;
      return {
        ...data,
        'id': id,
      };
    }).toList();
  }

  FirebaseFirestore get firestore => _firestore;
}