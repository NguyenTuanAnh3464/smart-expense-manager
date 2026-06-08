import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile_model.dart';

class ProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProfileService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _profileDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection("users").doc(uid);
  }

  Stream<UserProfileModel?> getProfileStream() {
    final doc = _profileDoc;
    if (doc == null) return Stream.value(null);

    return doc.snapshots().map((snapshot) {
      if (!snapshot.exists) return _authFallbackProfile();
      return UserProfileModel.fromFirestore(snapshot);
    });
  }

  Future<UserProfileModel?> getProfileOnce() async {
    final doc = _profileDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    if (!snapshot.exists) return _authFallbackProfile();
    return UserProfileModel.fromFirestore(snapshot);
  }

  Future<void> ensureProfileDocument() async {
    final user = _auth.currentUser;
    final doc = _profileDoc;
    if (user == null || doc == null) return;

    final snapshot = await doc.get();
    if (snapshot.exists) {
      final data = snapshot.data();
      final existingName =
          data?["name"]?.toString().trim().isNotEmpty == true ||
          data?["fullName"]?.toString().trim().isNotEmpty == true ||
          data?["displayName"]?.toString().trim().isNotEmpty == true;
      final existingPhoto =
          data?["photoUrl"]?.toString().trim().isNotEmpty == true ||
          data?["photoURL"]?.toString().trim().isNotEmpty == true ||
          data?["avatarUrl"]?.toString().trim().isNotEmpty == true ||
          data?["imageUrl"]?.toString().trim().isNotEmpty == true ||
          data?["profileImage"]?.toString().trim().isNotEmpty == true;
      await doc.set({
        "uid": user.uid,
        if (!existingName && user.displayName?.trim().isNotEmpty == true)
          "name": user.displayName!.trim(),
        "email": user.email ?? "",
        if (!existingPhoto && user.photoURL?.trim().isNotEmpty == true)
          "photoUrl": user.photoURL!.trim(),
        if (!existingPhoto && user.photoURL?.trim().isNotEmpty == true)
          "photoURL": user.photoURL!.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await doc.set({
      "uid": user.uid,
      "name": user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : "Người dùng",
      "email": user.email ?? "",
      "photoUrl": user.photoURL,
      "photoURL": user.photoURL,
      "phone": user.phoneNumber,
      "currency": "VND",
      "compactDashboard": true,
      "monthlySummary": true,
      "spendingReminder": false,
      "biometricLock": false,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    final doc = _profileDoc;
    if (user == null || doc == null) return;

    final name = data["name"]?.toString().trim();
    if (name != null && name.isNotEmpty && name != user.displayName) {
      await user.updateDisplayName(name);
    }
    final photoUrl = _firstNonEmpty(data["photoUrl"], data["photoURL"]);
    final normalizedPhotoUrl = photoUrl?.isEmpty == true ? null : photoUrl;
    if (normalizedPhotoUrl != user.photoURL) {
      await user.updatePhotoURL(normalizedPhotoUrl);
    }

    await doc.set({
      "uid": user.uid,
      "email": user.email ?? data["email"] ?? "",
      if (name != null && name.isNotEmpty) "displayName": name,
      ...data,
      "photoUrl": normalizedPhotoUrl,
      "photoURL": normalizedPhotoUrl,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  UserProfileModel? _authFallbackProfile() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return UserProfileModel(
      uid: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : "Người dùng",
      email: user.email ?? "",
      photoURL: user.photoURL,
      phone: user.phoneNumber,
      createdAt: user.metadata.creationTime,
      updatedAt: user.metadata.lastSignInTime,
    );
  }

  String? _firstNonEmpty(Object? first, Object? second) {
    for (final value in [first, second]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
