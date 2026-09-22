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

    return document.data();
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
      return {
        'id': document.id,
        ...document.data(),
      };
    }).toList();
  }
}