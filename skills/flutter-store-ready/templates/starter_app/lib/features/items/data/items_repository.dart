import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../domain/item.dart';

abstract interface class ItemsRepository {
  Future<ItemPage> fetchPage({String? cursor, CancelToken? cancelToken});

  /// Throws [NotFoundFailure] when the item does not exist.
  Future<Item> fetchById(String id, {CancelToken? cancelToken});
}

final class HttpItemsRepository implements ItemsRepository {
  HttpItemsRepository(this._dio);

  static const int pageSize = 20;
  final Dio _dio;

  @override
  Future<ItemPage> fetchPage({String? cursor, CancelToken? cancelToken}) =>
      guardFailures(() async {
        final response = await _dio.get<Object?>(
          '/items',
          queryParameters: {'limit': pageSize, 'cursor': ?cursor},
          cancelToken: cancelToken,
        );
        final body = response.data;
        if (body is! Map || body['items'] is! List) {
          throw const FormatException('Invalid items response');
        }
        final next = body['next_cursor'];
        return ItemPage(
          items: [for (final raw in body['items'] as List) Item.fromJson(raw)],
          nextCursor: next is String && next.isNotEmpty ? next : null,
        );
      });

  @override
  Future<Item> fetchById(String id, {CancelToken? cancelToken}) =>
      guardFailures(() async {
        final response = await _dio.get<Object?>(
          // Encode untrusted ids: never concatenate raw input into a path.
          '/items/${Uri.encodeComponent(id)}',
          cancelToken: cancelToken,
        );
        return Item.fromJson(response.data);
      });
}

/// Deterministic fake data source (45 items, pages of 20).
final class FakeItemsRepository implements ItemsRepository {
  FakeItemsRepository({
    this.latency = const Duration(milliseconds: 500),
    this.total = 45,
  });

  final Duration latency;
  final int total;

  /// Set to make the next call fail (useful in tests and demos).
  AppFailure? nextFailure;

  late final List<Item> _all = List.generate(
    total,
    (i) => Item(
      id: 'item_${i + 1}',
      title: 'Kayıt ${i + 1}',
      description:
          'Bu, ${i + 1}. örnek kaydın açıklamasıdır. Uzun metinlerin farklı '
          'ekran boyutlarında doğru sarıldığını göstermek için yeterince uzundur.',
      updatedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i * 7)),
    ),
  );

  @override
  Future<ItemPage> fetchPage({String? cursor, CancelToken? cancelToken}) async {
    await Future<void>.delayed(latency);
    _throwIfRequested();
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = (start + HttpItemsRepository.pageSize).clamp(0, _all.length);
    return ItemPage(
      items: _all.sublist(start.clamp(0, _all.length), end),
      nextCursor: end < _all.length ? '$end' : null,
    );
  }

  @override
  Future<Item> fetchById(String id, {CancelToken? cancelToken}) async {
    await Future<void>.delayed(latency);
    _throwIfRequested();
    for (final item in _all) {
      if (item.id == id) return item;
    }
    throw const NotFoundFailure();
  }

  void _throwIfRequested() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }
}
