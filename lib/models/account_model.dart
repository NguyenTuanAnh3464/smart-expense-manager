import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String? id;
  final String? userId;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final bool isDefault;
  final String? icon;
  final int? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AccountModel({
    this.id,
    this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = "VND",
    this.isDefault = false,
    this.icon,
    this.color,
    this.createdAt,
    this.updatedAt,
  });

  AccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? balance,
    String? currency,
    bool? isDefault,
    String? icon,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isDefault: isDefault ?? this.isDefault,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AccountModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AccountModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory AccountModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return AccountModel(
      id: id ?? data["id"]?.toString(),
      userId: data["userId"]?.toString(),
      name: data["name"]?.toString().trim().isNotEmpty == true
          ? data["name"].toString()
          : "Tài khoản",
      type: _normalizeType(data["type"]?.toString()),
      balance: _parseAmount(data["balance"]),
      currency: data["currency"]?.toString().trim().isNotEmpty == true
          ? data["currency"].toString()
          : "VND",
      isDefault: data["isDefault"] == true,
      icon: data["icon"]?.toString(),
      color: _parseColor(data["color"]),
      createdAt: _parseDate(data["createdAt"]),
      updatedAt: _parseDate(data["updatedAt"]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (userId != null) "userId": userId,
      "name": name,
      "type": _normalizeType(type),
      "balance": balance,
      "currency": currency,
      "isDefault": isDefault,
      if (icon != null) "icon": icon,
      if (color != null) "color": color,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  static String _normalizeType(String? value) {
    final raw = (value ?? "").trim().toLowerCase();
    if (raw == "ewallet" || raw == "e_wallet" || raw == "e-wallet") {
      return "ewallet";
    }
    if (raw == "bank" || raw == "bankaccount") return "bank";
    if (raw == "card" || raw == "creditcard") return "card";
    if (raw == "other") return "other";
    return raw.isEmpty ? "cash" : raw;
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(",", "").trim()) ?? 0;
    }
    return 0;
  }

  static int? _parseColor(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
