import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  final String uid;
  final String name;
  final String email;
  final String? photoURL;
  final String? phone;
  final String currency;
  final bool compactDashboard;
  final bool monthlySummary;
  final bool spendingReminder;
  final bool biometricLock;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoURL,
    this.phone,
    this.currency = "VND",
    this.compactDashboard = true,
    this.monthlySummary = true,
    this.spendingReminder = false,
    this.biometricLock = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final name =
        _firstNonEmpty(data["name"], data["fullName"], data["displayName"]) ??
        "Người dùng";
    return UserProfileModel(
      uid: data["uid"]?.toString() ?? doc.id,
      name: name,
      email: data["email"]?.toString() ?? "",
      photoURL: _firstNonEmpty(
        data["photoUrl"],
        data["photoURL"],
        data["avatarUrl"],
        data["imageUrl"],
        data["profileImage"],
      ),
      phone: data["phone"]?.toString(),
      currency: data["currency"]?.toString() ?? "VND",
      compactDashboard: data["compactDashboard"] != false,
      monthlySummary: data["monthlySummary"] != false,
      spendingReminder: data["spendingReminder"] == true,
      biometricLock: data["biometricLock"] == true,
      createdAt: _parseDate(data["createdAt"]),
      updatedAt: _parseDate(data["updatedAt"]),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _firstNonEmpty(
    Object? first,
    Object? second,
    Object? third, [
    Object? fourth,
    Object? fifth,
  ]) {
    for (final value in [first, second, third, fourth, fifth]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
