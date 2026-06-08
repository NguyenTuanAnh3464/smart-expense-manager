import 'package:flutter_test/flutter_test.dart';
import 'package:smart_expense_manager/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    test('normalizes negative amounts to positive values for old data', () {
      final transaction = TransactionModel.fromMap({
        'amount': -150000,
        'type': 'income',
        'category': 'Lương',
        'date': DateTime(2026, 6, 8),
      });

      expect(transaction.amount, 150000);
      expect(transaction.isIncome, isTrue);
    });

    test('falls back safely when optional Firestore fields are missing', () {
      final transaction = TransactionModel.fromMap({});

      expect(transaction.category, 'Khác');
      expect(transaction.amount, 0);
      expect(transaction.type, 'expense');
      expect(transaction.date, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('normalizes Vietnamese and English transaction types', () {
      expect(TransactionModel.normalizeType('tiền thu'), 'income');
      expect(TransactionModel.normalizeType('income'), 'income');
      expect(TransactionModel.normalizeType('tiền chi'), 'expense');
      expect(TransactionModel.normalizeType('expense'), 'expense');
      expect(TransactionModel.normalizeType(null), 'expense');
    });
  });
}
