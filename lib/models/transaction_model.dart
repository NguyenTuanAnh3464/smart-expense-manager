class TransactionModel {
  final String category;
  final double amount;
  final String note;
  final String type;
  final DateTime date;

  TransactionModel({
    required this.category,
    required this.amount,
    required this.note,
    required this.type,
    required this.date,
  });
}