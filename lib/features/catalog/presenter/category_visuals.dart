import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:flutter/material.dart';

/// Icon and colour handling for categories.
///
/// This lived in `core/` and did not belong there: it is the presentation of
/// one feature, not global visual infrastructure, and its presence in `core`
/// was what made both repositories import Material in order to construct an
/// entity — infrastructure depending on the framework's paint.
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

/// The colours someone can pick for a category.
///
/// Separate from `CompassoPalette.categorical`, which is the chart palette: this
/// one is **stored data** — `categories.color` has held a hex string since the
/// first migration — so changing an entry only affects categories created from
/// here on. Rows already in the database keep whatever they were given.
///
/// The first twelve were never measured. `#8D6414` was ochre, which the design
/// system removed from the product entirely, and several pairs sat within a few
/// points of luminance of each other. These are drawn from the same search that
/// produced the chart palette: no yellow band, and a spread in lightness rather
/// than only in hue.
const categoryColors = <Color>[
  Color(0xFF06485B),
  Color(0xFF8D2F36),
  Color(0xFF695299),
  Color(0xFF177B63),
  Color(0xFF677B98),
  Color(0xFF788E57),
  Color(0xFF4F8397),
  Color(0xFFB05A63),
  Color(0xFF5E4A8C),
  Color(0xFF2F6F5B),
  Color(0xFF8A6A8C),
  Color(0xFF3B5C8A),
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

/// Resolves a stored category into the two Flutter types it draws as.
///
/// An extension rather than fields on the entity, so every call site keeps
/// reading `category.icon` and `category.color` while the rules layer holds
/// nothing but strings.
extension CategoryVisuals on FinanceCategory {
  IconData get icon => categoryIconFor(iconName);
  Color get color => parseCategoryColor(colorHex);
}

extension CategoryDraftVisuals on CategoryDraft {
  Color get color => parseCategoryColor(colorHex);
  IconData get icon => categoryIconFor(iconName);
}
