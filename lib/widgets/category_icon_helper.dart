import 'package:flutter/material.dart';

class CategoryIconOption {
  final String name;
  final IconData icon;

  const CategoryIconOption(this.name, this.icon);
}

const List<CategoryIconOption> categoryIconOptions = [
  CategoryIconOption("restaurant", Icons.restaurant),
  CategoryIconOption("fastfood", Icons.fastfood),
  CategoryIconOption("local_cafe", Icons.local_cafe),
  CategoryIconOption("local_bar", Icons.local_bar),
  CategoryIconOption("bakery_dining", Icons.bakery_dining),
  CategoryIconOption("lunch_dining", Icons.lunch_dining),
  CategoryIconOption("ramen_dining", Icons.ramen_dining),
  CategoryIconOption("icecream", Icons.icecream),
  CategoryIconOption("grocery", Icons.local_grocery_store),
  CategoryIconOption("shopping_basket", Icons.shopping_basket),
  CategoryIconOption("directions_car", Icons.directions_car),
  CategoryIconOption("local_taxi", Icons.local_taxi),
  CategoryIconOption("train", Icons.train),
  CategoryIconOption("flight", Icons.flight),
  CategoryIconOption("two_wheeler", Icons.two_wheeler),
  CategoryIconOption("directions_bus", Icons.directions_bus),
  CategoryIconOption("subway", Icons.subway),
  CategoryIconOption("local_gas_station", Icons.local_gas_station),
  CategoryIconOption("airport_shuttle", Icons.airport_shuttle),
  CategoryIconOption("shopping_cart", Icons.shopping_cart),
  CategoryIconOption("shopping_bag", Icons.shopping_bag),
  CategoryIconOption("store", Icons.store),
  CategoryIconOption("local_mall", Icons.local_mall),
  CategoryIconOption("checkroom", Icons.checkroom),
  CategoryIconOption("dry_cleaning", Icons.dry_cleaning),
  CategoryIconOption("watch", Icons.watch),
  CategoryIconOption("diamond", Icons.diamond),
  CategoryIconOption("home", Icons.home),
  CategoryIconOption("house", Icons.house),
  CategoryIconOption("apartment", Icons.apartment),
  CategoryIconOption("chair", Icons.chair),
  CategoryIconOption("bed", Icons.bed),
  CategoryIconOption("kitchen", Icons.kitchen),
  CategoryIconOption("lightbulb", Icons.lightbulb),
  CategoryIconOption("water_drop", Icons.water_drop),
  CategoryIconOption("electrical_services", Icons.electrical_services),
  CategoryIconOption("cleaning_services", Icons.cleaning_services),
  CategoryIconOption("school", Icons.school),
  CategoryIconOption("menu_book", Icons.menu_book),
  CategoryIconOption("edit_note", Icons.edit_note),
  CategoryIconOption("laptop", Icons.laptop),
  CategoryIconOption("work", Icons.work),
  CategoryIconOption("business_center", Icons.business_center),
  CategoryIconOption("print", Icons.print),
  CategoryIconOption("calculate", Icons.calculate),
  CategoryIconOption("medical_services", Icons.medical_services),
  CategoryIconOption("local_hospital", Icons.local_hospital),
  CategoryIconOption("medication", Icons.medication),
  CategoryIconOption("health_and_safety", Icons.health_and_safety),
  CategoryIconOption("fitness_center", Icons.fitness_center),
  CategoryIconOption("sports_gymnastics", Icons.sports_gymnastics),
  CategoryIconOption("spa", Icons.spa),
  CategoryIconOption("movie", Icons.movie),
  CategoryIconOption("sports_esports", Icons.sports_esports),
  CategoryIconOption("music_note", Icons.music_note),
  CategoryIconOption("sports_soccer", Icons.sports_soccer),
  CategoryIconOption("sports_basketball", Icons.sports_basketball),
  CategoryIconOption("celebration", Icons.celebration),
  CategoryIconOption("photo_camera", Icons.photo_camera),
  CategoryIconOption("travel_explore", Icons.travel_explore),
  CategoryIconOption("account_balance_wallet", Icons.account_balance_wallet),
  CategoryIconOption("account_balance", Icons.account_balance),
  CategoryIconOption("credit_card", Icons.credit_card),
  CategoryIconOption("payments", Icons.payments),
  CategoryIconOption("savings", Icons.savings),
  CategoryIconOption("attach_money", Icons.attach_money),
  CategoryIconOption("currency_exchange", Icons.currency_exchange),
  CategoryIconOption("receipt_long", Icons.receipt_long),
  CategoryIconOption("paid", Icons.paid),
  CategoryIconOption("person", Icons.person),
  CategoryIconOption("family_restroom", Icons.family_restroom),
  CategoryIconOption("pets", Icons.pets),
  CategoryIconOption("phone_android", Icons.phone_android),
  CategoryIconOption("wifi", Icons.wifi),
  CategoryIconOption("card_giftcard", Icons.card_giftcard),
  CategoryIconOption("volunteer_activism", Icons.volunteer_activism),
  CategoryIconOption("star", Icons.star),
  CategoryIconOption("favorite", Icons.favorite),
  CategoryIconOption("category", Icons.category),
  CategoryIconOption("more_horiz", Icons.more_horiz),
];

IconData getCategoryIcon(String? iconName) {
  final normalized = iconName?.trim();
  if (normalized == null || normalized.isEmpty) return Icons.category;
  for (final option in categoryIconOptions) {
    if (option.name == normalized) return option.icon;
  }
  return Icons.category;
}

String getCategoryIconName(IconData icon) {
  for (final option in categoryIconOptions) {
    if (option.icon.codePoint == icon.codePoint &&
        option.icon.fontFamily == icon.fontFamily) {
      return option.name;
    }
  }
  return "category";
}

Color getCategoryColor(dynamic colorValue, {Color fallback = Colors.green}) {
  if (colorValue is Color) return colorValue;
  if (colorValue is int) return Color(colorValue);
  if (colorValue is num) return Color(colorValue.toInt());
  if (colorValue is String) {
    final text = colorValue.trim();
    final parsedDecimal = int.tryParse(text);
    if (parsedDecimal != null) return Color(parsedDecimal);

    final normalized = text
        .replaceFirst("#", "")
        .replaceFirst("0x", "")
        .replaceFirst("0X", "");
    final parsedHex = int.tryParse(normalized, radix: 16);
    if (parsedHex != null) {
      return Color(normalized.length <= 6 ? 0xFF000000 | parsedHex : parsedHex);
    }
  }
  return fallback;
}

IconData getTransactionIconFromData({
  required Object? type,
  String? categoryIconName,
}) {
  final iconName = categoryIconName?.trim();
  if (iconName != null && iconName.isNotEmpty) {
    return getCategoryIcon(iconName);
  }

  final normalizedType = type?.toString().trim().toLowerCase() ?? "";
  if (normalizedType == "income" || normalizedType.contains("income")) {
    return Icons.account_balance_wallet;
  }
  if (normalizedType == "saving" ||
      normalizedType == "transfer_to_saving" ||
      normalizedType == "budget_to_saving") {
    return Icons.savings;
  }
  return Icons.shopping_bag;
}

Color getTransactionColorFromData({
  required Object? type,
  Object? categoryColorValue,
}) {
  if (categoryColorValue != null) {
    return getCategoryColor(categoryColorValue);
  }

  final normalizedType = type?.toString().trim().toLowerCase() ?? "";
  if (normalizedType == "income" || normalizedType.contains("income")) {
    return Colors.green;
  }
  if (normalizedType == "saving" ||
      normalizedType == "transfer_to_saving" ||
      normalizedType == "budget_to_saving") {
    return Colors.blue;
  }
  return Colors.redAccent;
}
