import '../models/transaction_model.dart';

class AIService {
  Future<String?> suggestCategory({
    required String note,
    required double amount,
    required String type,
  }) async {
    final cleanedNote = _shorten(note, 80);
    if (cleanedNote.isEmpty || amount < 0) return null;

    return _localCategorySuggestion(
      note: cleanedNote,
      type: TransactionModel.normalizeType(type),
    );
  }

  String _localCategorySuggestion({
    required String note,
    required String type,
  }) {
    final lower = _normalize(note);
    if (type == "income") {
      if (_containsAny(lower, ["luong", "salary", "payroll"])) {
        return "Tiền lương";
      }
      if (_containsAny(lower, ["thuong", "bonus"])) return "Tiền thưởng";
      if (_containsAny(lower, ["phu cap", "allowance"])) {
        return "Tiền phụ cấp";
      }
      if (_containsAny(lower, ["dau tu", "lai", "co tuc"])) return "Đầu tư";
      return "Thu nhập phụ";
    }

    if (_containsAny(lower, [
      "an",
      "com",
      "bun",
      "pho",
      "sang",
      "trua",
      "toi",
      "cafe",
      "ca phe",
      "tra sua",
    ])) {
      return "Ăn uống";
    }
    if (_containsAny(lower, ["xang", "grab", "taxi", "bus", "xe", "di lai"])) {
      return "Đi lại";
    }
    if (_containsAny(lower, ["ao", "quan", "giay", "vay"])) return "Quần áo";
    if (_containsAny(lower, ["son", "kem", "my pham"])) return "Mỹ phẩm";
    if (_containsAny(lower, ["thuoc", "benh", "kham", "vien"])) return "Y tế";
    if (_containsAny(lower, ["hoc", "sach", "khoa", "truong"])) {
      return "Giáo dục";
    }
    if (_containsAny(lower, ["dien", "evn"])) return "Tiền điện";
    if (_containsAny(lower, ["nha", "tro", "thue"])) return "Tiền nhà";
    return "Khác";
  }

  bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  String _shorten(String value, int maxLength) {
    final cleaned = value.trim().replaceAll(RegExp(r"\s+"), " ");
    if (cleaned.length <= maxLength) return cleaned;
    return "${cleaned.substring(0, maxLength)}...";
  }

  String _normalize(String value) {
    var text = value.toLowerCase().trim();
    const chars = {
      "à": "a", "á": "a", "ạ": "a", "ả": "a", "ã": "a",
      "â": "a", "ầ": "a", "ấ": "a", "ậ": "a", "ẩ": "a", "ẫ": "a",
      "ă": "a", "ằ": "a", "ắ": "a", "ặ": "a", "ẳ": "a", "ẵ": "a",
      "è": "e", "é": "e", "ẹ": "e", "ẻ": "e", "ẽ": "e",
      "ê": "e", "ề": "e", "ế": "e", "ệ": "e", "ể": "e", "ễ": "e",
      "ì": "i", "í": "i", "ị": "i", "ỉ": "i", "ĩ": "i",
      "ò": "o", "ó": "o", "ọ": "o", "ỏ": "o", "õ": "o",
      "ô": "o", "ồ": "o", "ố": "o", "ộ": "o", "ổ": "o", "ỗ": "o",
      "ơ": "o", "ờ": "o", "ớ": "o", "ợ": "o", "ở": "o", "ỡ": "o",
      "ù": "u", "ú": "u", "ụ": "u", "ủ": "u", "ũ": "u",
      "ư": "u", "ừ": "u", "ứ": "u", "ự": "u", "ử": "u", "ữ": "u",
      "ỳ": "y", "ý": "y", "ỵ": "y", "ỷ": "y", "ỹ": "y",
      "đ": "d",
    };
    chars.forEach((key, value) {
      text = text.replaceAll(key, value);
    });
    return text.replaceAll(RegExp(r"\s+"), " ");
  }
}
