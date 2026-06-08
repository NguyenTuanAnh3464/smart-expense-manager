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
      await doc.set({
        "uid": user.uid,
        "email": user.email ?? "",
        "photoURL": user.photoURL,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await doc.set({
      "uid": user.uid,
      "name": user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : "Người dùng",
      "email": user.email ?? "",
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

    await doc.set({
      "uid": user.uid,
      "email": user.email ?? data["email"] ?? "",
      ...data,
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
}
