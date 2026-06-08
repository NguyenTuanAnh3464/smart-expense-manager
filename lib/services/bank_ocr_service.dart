import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/bank_extracted_transaction.dart';

class BankOcrService {
  Future<String> extractTextFromImage(String imagePath) async {
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await textRecognizer.close();
    }
  }

  List<BankExtractedTransaction> parseBankTransactions(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return [];

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (_looksLikeSePayList(text)) {
      return _parseSePayList(lines);
    }

    if (_looksLikeSuccessReceipt(text)) {
      final receiptTransaction = _parseSuccessReceipt(lines);
      return receiptTransaction == null ? [] : [receiptTransaction];
    }

    final blocks = _splitIntoDateBlocks(lines);
    final transactions = <BankExtractedTransaction>[];

    for (final block in blocks) {
      final blockText = block.join(" ");
      final date = _parseDate(blockText);
      if (date == null) continue;

      final amount = _findBestAmountMatch(block);
      if (amount == null) continue;

      final type = _detectType(amount.rawAmount, blockText);

      transactions.add(
        BankExtractedTransaction(
          date: date,
          amount: amount.amount,
          content: "",
          currency: "VND",
          type: type,
          confidence: amount.hasAmountLabel || amount.nearSuccessLabel
              ? 0.88
              : 0.72,
          rawText: "",
          suggestedCategory: "Khác",
        ),
      );
    }

    return transactions;
  }

  bool _looksLikeSePayList(String text) {
    final lower = text.toLowerCase();
    return lower.contains("sepay") ||
        lower.contains("lịch sử giao dịch") ||
        lower.contains("lich su giao dich") ||
        (lower.contains("thời gian") && lower.contains("tất cả")) ||
        (lower.contains("thoi gian") && lower.contains("tat ca"));
  }

  List<BankExtractedTransaction> _parseSePayList(List<String> lines) {
    final transactions = <BankExtractedTransaction>[];
    final commonDate =
        _parseDateNearLabel(lines, ["thời gian", "thoi gian"]) ??
        _parseDate(lines.join(" "));
    final amountPattern = RegExp(
      r'([+-])\s*(\d{1,3}(?:[,.]\d{3})+|\d{3,9})',
      caseSensitive: false,
    );

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (_isIgnoredSePayAmountLine(line)) continue;

      for (final match in amountPattern.allMatches(line)) {
        final raw = match.group(0)?.trim();
        if (raw == null || raw.isEmpty) continue;

        final digitCount = raw.replaceAll(RegExp(r'[^\d]'), "").length;
        if (digitCount > 9) continue;

        final amount = _parseAmount(raw);
        if (amount <= 0) continue;

        final date = _findNearestDate(lines, index) ?? commonDate;
        if (date == null) continue;

        transactions.add(
          BankExtractedTransaction(
            date: date,
            amount: amount,
            content: "",
            currency: "VND",
            type: raw.replaceAll(" ", "").startsWith("-")
                ? "expense"
                : "income",
            confidence: 0.82,
            rawText: "",
            suggestedCategory: "Khác",
          ),
        );
      }
    }

    return transactions;
  }

  bool _looksLikeSuccessReceipt(String text) {
    final lower = text.toLowerCase();
    return lower.contains("giao dịch thành công") ||
        lower.contains("giao dich thanh cong");
  }

  BankExtractedTransaction? _parseSuccessReceipt(List<String> lines) {
    final receiptText = lines.join(" ");
    final date =
        _parseDateNearLabel(lines, ["thời gian giao dịch", "thoi gian giao dich"]) ??
        _parseDate(receiptText);
    final amount = _findReceiptAmount(lines);
    if (date == null || amount == null) return null;

    return BankExtractedTransaction(
      date: date,
      amount: amount.amount,
      content: "",
      currency: "VND",
      type: _detectType(amount.rawAmount, receiptText),
      confidence: 0.9,
      rawText: "",
      suggestedCategory: "Khác",
    );
  }

  List<List<String>> _splitIntoDateBlocks(List<String> lines) {
    final blocks = <List<String>>[];
    var current = <String>[];
    var prelude = <String>[];

    for (final line in lines) {
      if (_parseDate(line) != null) {
        if (current.isNotEmpty) blocks.add(current);
        current = [...prelude, line];
        prelude = [];
      } else if (current.isNotEmpty) {
        current.add(line);
      } else if (!_isGalleryNoise(line)) {
        prelude.add(line);
      }
    }

    if (current.isNotEmpty) blocks.add(current);
    return blocks;
  }

  DateTime? _parseDate(String text) {
    final datePattern = RegExp(
      r'\b(\d{1,2})\s*[\/\-\u2010\u2011\u2012\u2013\u2014\u2015\u2212]\s*(\d{1,2})(?:\s*[\/\-\u2010\u2011\u2012\u2013\u2014\u2015\u2212]\s*(\d{4}))?(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?\b',
    );

    final match = datePattern.firstMatch(text);
    if (match != null) {
      return _safeDate(
        day: match.group(1),
        month: match.group(2),
        year: match.group(3) ?? DateTime.now().year.toString(),
      );
    }

    return null;
  }

  DateTime? _parseDateNearLabel(List<String> lines, List<String> labels) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].toLowerCase();
      if (!labels.any(line.contains)) continue;

      final end = (index + 2).clamp(0, lines.length - 1);
      for (var i = index; i <= end; i++) {
        final date = _parseDate(lines[i]);
        if (date != null) return date;
      }
    }
    return null;
  }

  DateTime? _findNearestDate(List<String> lines, int amountLineIndex) {
    DateTime? bestDate;
    var bestDistance = 999;

    for (var index = 0; index < lines.length; index++) {
      final date = _parseDate(lines[index]);
      if (date == null) continue;
      final distance = (index - amountLineIndex).abs();
      if (distance <= 6 && distance < bestDistance) {
        bestDate = date;
        bestDistance = distance;
      }
    }

    return bestDate;
  }

  DateTime? _safeDate({
    required String? day,
    required String? month,
    required String? year,
  }) {
    final parsedDay = int.tryParse(day ?? "");
    final parsedMonth = int.tryParse(month ?? "");
    final parsedYear = int.tryParse(year ?? "");
    if (parsedDay == null || parsedMonth == null || parsedYear == null) {
      return null;
    }
    if (parsedMonth < 1 || parsedMonth > 12) return null;
    if (parsedDay < 1 || parsedDay > 31) return null;
    return DateTime(parsedYear, parsedMonth, parsedDay);
  }

  _AmountMatch? _findBestAmountMatch(List<String> block) {
    final pattern = RegExp(
      r'([+-]?)\s*(\d{1,3}(?:[,.]\d{3})+|\d+)\s*(VND|VNĐ|đ|Đ)',
      caseSensitive: false,
    );
    final matches = <_AmountMatch>[];
    final seen = <String>{};

    for (var index = 0; index < block.length; index++) {
      final line = block[index];
      for (final match in pattern.allMatches(line)) {
        final raw = match.group(0)?.trim();
        if (raw == null || raw.isEmpty) continue;

        final sign = match.group(1)?.trim() ?? "";
        final amount = _parseAmount(raw);
        if (amount <= 0) continue;

        final digitCount = raw.replaceAll(RegExp(r'[^\d]'), "").length;
        if (digitCount > 9) continue;

        final hasAmountLabel = _nearAmountLabel(block, index);
        final nearSuccessLabel = _nearSuccessLabel(block, index);
        final isNearTop = index <= 3;
        if (sign.isEmpty &&
            !hasAmountLabel &&
            !(nearSuccessLabel && isNearTop)) {
          continue;
        }
        if (_isRejectedMoneyContext(
          block,
          index,
          hasAmountLabel || nearSuccessLabel,
        )) {
          continue;
        }

        final key = "${raw.replaceAll(RegExp(r'\s+'), '')}:$amount";
        if (!seen.add(key)) continue;

        final score =
            (hasAmountLabel ? 100 : 0) +
            (nearSuccessLabel ? 80 : 0) +
            (isNearTop ? 20 : 0) +
            (sign.isNotEmpty ? 30 : 0) -
            index;
        matches.add(
          _AmountMatch(
            rawAmount: raw,
            amount: amount,
            score: score,
            hasAmountLabel: hasAmountLabel,
            nearSuccessLabel: nearSuccessLabel,
          ),
        );
      }
    }

    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.first;
  }

  _AmountMatch? _findReceiptAmount(List<String> lines) {
    final pattern = RegExp(
      r'([+-]?)\s*(\d{1,3}(?:[,.]\d{3})+|\d+)\s*(VND|VNĐ|đ|Đ)',
      caseSensitive: false,
    );
    final successIndex = _firstSuccessLineIndex(lines);
    final matches = <_AmountMatch>[];
    final seen = <String>{};

    for (var index = 0; index < lines.length; index++) {
      if (_isGalleryNoise(lines[index])) continue;

      for (final match in pattern.allMatches(lines[index])) {
        final raw = match.group(0)?.trim();
        if (raw == null || raw.isEmpty) continue;

        final amount = _parseAmount(raw);
        if (amount <= 0) continue;

        final digitCount = raw.replaceAll(RegExp(r'[^\d]'), "").length;
        if (digitCount > 9) continue;

        if (_isRejectedReceiptMoneyContext(lines, index)) continue;

        final key = "${raw.replaceAll(RegExp(r'\s+'), '')}:$amount";
        if (!seen.add(key)) continue;

        final distanceFromSuccess = successIndex == null
            ? 20
            : (index - successIndex).abs();
        final isNearTop = index <= 5;
        final hasAmountLabel = _nearAmountLabel(lines, index);
        final score =
            120 -
            distanceFromSuccess * 8 +
            (hasAmountLabel ? 60 : 0) +
            (isNearTop ? 25 : 0);

        matches.add(
          _AmountMatch(
            rawAmount: raw,
            amount: amount,
            score: score,
            hasAmountLabel: hasAmountLabel,
            nearSuccessLabel: true,
          ),
        );
      }
    }

    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.first;
  }

  int? _firstSuccessLineIndex(List<String> lines) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].toLowerCase();
      if (line.contains("giao dịch thành công") ||
          line.contains("giao dich thanh cong") ||
          line.contains("thành công") ||
          line.contains("thanh cong")) {
        return index;
      }
    }
    return null;
  }

  double _parseAmount(String value) {
    final normalized = value.replaceAll(RegExp(r'[^\d]'), "");
    return double.tryParse(normalized) ?? 0;
  }

  bool _nearAmountLabel(List<String> lines, int index) {
    final start = (index - 1).clamp(0, lines.length - 1);
    final end = (index + 1).clamp(0, lines.length - 1);
    for (var i = start; i <= end; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains("số tiền") ||
          line.contains("so tien") ||
          line.contains("amount")) {
        return true;
      }
    }
    return false;
  }

  bool _nearSuccessLabel(List<String> lines, int index) {
    final start = (index - 2).clamp(0, lines.length - 1);
    final end = (index + 2).clamp(0, lines.length - 1);
    for (var i = start; i <= end; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains("giao dịch thành công") ||
          line.contains("giao dich thanh cong") ||
          line.contains("thành công") ||
          line.contains("thanh cong")) {
        return true;
      }
    }
    return false;
  }

  bool _isRejectedMoneyContext(
    List<String> lines,
    int index,
    bool hasAmountLabel,
  ) {
    final start = (index - 2).clamp(0, lines.length - 1);
    final end = (index + 2).clamp(0, lines.length - 1);
    final context = lines.sublist(start, end + 1).join(" ").toLowerCase();

    if (hasAmountLabel) return false;

    if (context.contains("số dư") ||
        context.contains("so du") ||
        context.contains("balance") ||
        context.contains("phí") ||
        context.contains("phi") ||
        context.contains("fee")) {
      return true;
    }

    return context.contains("tài khoản") ||
        context.contains("tai khoan") ||
        context.contains("account") ||
        context.contains("stk") ||
        context.contains("ref") ||
        context.contains("mã giao dịch") ||
        context.contains("ma giao dich") ||
        context.contains("điện thoại") ||
        context.contains("dien thoai");
  }

  bool _isRejectedReceiptMoneyContext(List<String> lines, int index) {
    final start = (index - 2).clamp(0, lines.length - 1);
    final end = (index + 2).clamp(0, lines.length - 1);
    final context = lines.sublist(start, end + 1).join(" ").toLowerCase();

    return context.contains("số dư") ||
        context.contains("so du") ||
        context.contains("balance") ||
        context.contains("miễn phí") ||
        context.contains("mien phi") ||
        context.contains("phí") ||
        context.contains("phi") ||
        context.contains("fee");
  }

  bool _isGalleryNoise(String line) {
    final text = line.trim().toLowerCase();
    if (text.isEmpty) return true;
    if (text.contains("items.") || text.contains("item.")) return true;
    if (text == "hôm nay" || text == "hom nay") return true;
    if (text == "4g" || text == "5g" || text == "lte") return true;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(text)) return true;
    if (RegExp(r'\.(jpg|jpeg|png|webp|heic)$').hasMatch(text)) return true;
    return false;
  }

  bool _isIgnoredSePayAmountLine(String line) {
    final text = line.trim().toLowerCase();
    if (_isGalleryNoise(line)) return true;
    if (text.contains("pin") ||
        text.contains("4g") ||
        text.contains("5g") ||
        text.contains("lte") ||
        text.contains("tất cả") ||
        text.contains("tat ca") ||
        text.contains("thời gian") ||
        text.contains("thoi gian")) {
      return true;
    }
    return false;
  }

  String _detectType(String rawAmount, String blockText) {
    final compactAmount = rawAmount.replaceAll(" ", "");
    if (compactAmount.startsWith("+")) return "income";
    if (compactAmount.startsWith("-")) return "expense";
    final lower = blockText.toLowerCase();
    if (lower.contains("chuyển tiền") ||
        lower.contains("chuyen tien") ||
        lower.contains("người thụ hưởng") ||
        lower.contains("nguoi thu huong") ||
        lower.contains("giao dịch thành công") ||
        lower.contains("giao dich thanh cong")) {
      return "expense";
    }
    return "unknown";
  }
}

class _AmountMatch {
  final String rawAmount;
  final double amount;
  final int score;
  final bool hasAmountLabel;
  final bool nearSuccessLabel;

  const _AmountMatch({
    required this.rawAmount,
    required this.amount,
    required this.score,
    required this.hasAmountLabel,
    required this.nearSuccessLabel,
  });
}
