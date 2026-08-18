import 'package:flutter/material.dart';

/// Icon and colour handling for categories.
///
/// `categories.color` and `categories.icon` have existed in the schema since
/// the first migration and were never read: the app assigned a colour by list
/// position and drew the same icon for every category. Letting someone pick
/// either one only means something once these are honoured.
///
/// The catalogue is a fixed map rather than a lookup by code point, because
/// Flutter tree-shakes icons and a dynamically constructed `IconData` would be
/// stripped from the build and render as a blank box.
const categoryIcons = <String, IconData>{
  'category': Icons.category_rounded,
  'restaurant': Icons.restaurant_rounded,
  'cart': Icons.shopping_cart_rounded,
  'bag': Icons.shopping_bag_rounded,
  'car': Icons.directions_car_rounded,
  'bus': Icons.directions_bus_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'home': Icons.home_rounded,
  'bolt': Icons.bolt_rounded,
  'health': Icons.favorite_rounded,
  'pharmacy': Icons.medical_services_rounded,
  'school': Icons.school_rounded,
  'sports': Icons.sports_soccer_rounded,
  'movie': Icons.movie_rounded,
  'flight': Icons.flight_rounded,
  'hotel': Icons.hotel_rounded,
  'pets': Icons.pets_rounded,
  'gift': Icons.card_giftcard_rounded,
  'subscriptions': Icons.subscriptions_rounded,
  'phone': Icons.smartphone_rounded,
  'bank': Icons.account_balance_rounded,
  'transfer': Icons.swap_horiz_rounded,
  'savings': Icons.savings_rounded,
  'work': Icons.work_rounded,
  'child': Icons.child_care_rounded,
  'build': Icons.build_rounded,
  'more': Icons.more_horiz_rounded,
};

/// Falls back to the neutral icon rather than failing: a category whose icon
/// name is unknown should still render.
IconData categoryIconFor(String? name) =>
    categoryIcons[name] ?? Icons.category_rounded;

String categoryIconName(IconData icon) => categoryIcons.entries
    .firstWhere(
      (entry) => entry.value == icon,
      orElse: () => const MapEntry('category', Icons.category_rounded),
    )
    .key;

/// A palette wide enough to tell a dozen categories apart, with every entry
/// legible against both the page and the card surface.
const categoryColors = <Color>[
  Color(0xFF1F6B4F),
  Color(0xFFB23F22),
  Color(0xFF4A5488),
  Color(0xFF8D6414),
  Color(0xFFBF5C7A),
  Color(0xFF377D71),
  Color(0xFF7D63A8),
  Color(0xFF477D9B),
  Color(0xFF98734E),
  Color(0xFF6B7B58),
  Color(0xFF4B6473),
  Color(0xFF8A5A3B),
];

/// Parses `#RRGGBB` or `RRGGBB`, tolerating an alpha prefix.
Color parseCategoryColor(String? value) {
  final text = (value ?? '').replaceAll('#', '').trim();
  if (text.length != 6 && text.length != 8) return categoryColors.first;
  final parsed = int.tryParse(text, radix: 16);
  if (parsed == null) return categoryColors.first;
  return Color(text.length == 6 ? 0xFF000000 | parsed : parsed);
}

/// Back to the `#RRGGBB` the column expects.
String categoryColorHex(Color color) {
  String channel(double value) =>
      ((value * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'
      .toUpperCase();
}
