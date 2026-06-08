import 'package:cloud_firestore/cloud_firestore.dart';

class SavingGoalModel {
  final String? id;
  final String? userId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SavingGoalModel({
    this.id,
    this.userId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    this.createdAt,
    this.updatedAt,
  });

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  SavingGoalModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SavingGoalModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SavingGoalModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory SavingGoalModel.fromMap(Map<String, dynamic> data, {String? id}) {
    final title = data["title"]?.toString().trim();
    return SavingGoalModel(
      id: id ?? data["id"]?.toString(),
      userId: data["userId"]?.toString(),
      title: title?.isNotEmpty == true ? title! : "Mục tiêu tiết kiệm",
      targetAmount: _parseAmount(data["targetAmount"]),
      currentAmount: _parseAmount(data["currentAmount"]),
      deadline: _parseDate(data["deadline"]) ?? DateTime.now(),
      createdAt: _parseDate(data["createdAt"]),
      updatedAt: _parseDate(data["updatedAt"]),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (userId != null) "userId": userId,
      "title": title.trim(),
      "targetAmount": targetAmount,
      "currentAmount": currentAmount,
      "deadline": Timestamp.fromDate(deadline),
    };
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble().abs();
    if (value is String) {
      return (double.tryParse(value.replaceAll(",", "").trim()) ?? 0).abs();
    }
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
