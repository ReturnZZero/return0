import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String tourPlacesCollection = 'tour_places';
  static const int _maxBatchSize = 400;

  Future<bool> hasTourPlaces() async {
    final snapshot = await _firestore
        .collection(tourPlacesCollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<int> upsertTourPlaces(List<Map<String, dynamic>> places) async {
    if (places.isEmpty) {
      return 0;
    }

    var savedCount = 0;

    for (var i = 0; i < places.length; i += _maxBatchSize) {
      final chunk = places.skip(i).take(_maxBatchSize).toList();
      final batch = _firestore.batch();

      for (final place in chunk) {
        final documentId = '${place['contentId'] ?? place['contentid'] ?? ''}'
            .trim();
        if (documentId.isEmpty) {
          continue;
        }

        final docRef = _firestore
            .collection(tourPlacesCollection)
            .doc(documentId);
        batch.set(docRef, {
          ...place,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        savedCount++;
      }

      await batch.commit();
    }

    return savedCount;
  }
}
