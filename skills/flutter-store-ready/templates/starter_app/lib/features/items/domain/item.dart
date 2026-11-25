import 'package:flutter/foundation.dart';

@immutable
final class Item {
  const Item({
    required this.id,
    required this.title,
    required this.description,
    required this.updatedAt,
  });

  factory Item.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Item must be an object');
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final updatedAt = DateTime.tryParse(json['updated_at'] as String? ?? '');
    if (id is! String || title is! String || updatedAt == null) {
      throw const FormatException('Item has missing or invalid fields');
    }
    return Item(
      id: id,
      title: title,
      // Optional field: tolerate absence instead of failing the whole page.
      description: description is String ? description : '',
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String title;
  final String description;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) => other is Item && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One page of a cursor-paginated list.
@immutable
final class ItemPage {
  const ItemPage({required this.items, required this.nextCursor});

  final List<Item> items;

  /// Null when there are no more pages.
  final String? nextCursor;
}
